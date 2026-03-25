<#if license??>
${js.license(license)}
</#if>
class Remote {
  /**
   * 构造函数
   * @param {Object} options - 配置选项
   */
  constructor(options = {}) {
    // 基础配置
    this.configURL = options.configURL || '/api/internal';
    this.timeout = options.timeout || 60000;
    this.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...options.headers
    };
    
    // 运行时状态
    this.baseURL = null;
    this.token = null;
    this.refreshToken = null;
    this.tokenExpiresAt = null;
    this.config = null;
    this.configLastFetch = 0;
    this.configCacheTime = 5 * 60 * 1000; // 5分钟
    
    // 重试配置
    this.retryConfig = {
      maxAttempts: options.maxAttempts || 3,
      baseDelay: options.baseDelay || 1000,
      maxDelay: options.maxDelay || 10000,
      retryableStatuses: [408, 429, 500, 502, 503, 504],
      ...options.retry
    };
    
    // Token刷新配置
    this.tokenConfig = {
      bufferTime: options.tokenBufferTime || 60 * 1000, // 提前1分钟刷新
      refreshURL: options.tokenRefreshURL || '/auth/refresh',
      ...options.token
    };
    
    // 熔断器状态
    this.circuitState = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
    this.failureCount = 0;
    this.successCount = 0;
    this.circuitFailureThreshold = options.circuitFailureThreshold || 5;
    this.circuitSuccessThreshold = options.circuitSuccessThreshold || 3;
    this.circuitTimeout = options.circuitTimeout || 60000;
    this.circuitNextAttempt = null;
    
    // 拦截器
    this.requestInterceptors = [];
    this.responseInterceptors = [];
    this.errorInterceptors = [];
    
    // Token刷新锁
    this.refreshPromise = null;
  }

  // ==================== 初始化 ====================

  /**
   * 初始化Remote（必须首先调用）
   */
  async init() {
    await this._loadConfig();
    return this;
  }

  /**
   * 加载配置
   */
  async _loadConfig(force = false) {
    const now = Date.now();
    
    if (!force && this.config && (now - this.configLastFetch) < this.configCacheTime) {
      return this.config;
    }

    try {
      const response = await fetch(this.configURL, {
        method: 'GET',
        headers: { 'Accept': 'application/json' }
      });

      if (!response.ok) {
        throw new Error(`获取配置失败: ${response.status}`);
      }

      this.config = await response.json();
      this.configLastFetch = now;
      
      // 应用配置
      this.baseURL = this.config.apiBaseURL || this.config.baseURL || '/api/v1';
      
      if (this.config.timeout) {
        this.timeout = this.config.timeout;
      }
      
      if (this.config.headers) {
        this.headers = { ...this.headers, ...this.config.headers };
      }
      
      // 设置初始Token
      if (this.config.initialToken) {
        this._setTokens({
          token: this.config.initialToken,
          refreshToken: this.config.initialRefreshToken,
          expiresIn: this.config.tokenExpiresIn || 3600
        });
      }
      
      return this.config;
    } catch (error) {
      if (this.config) {
        console.warn('使用缓存配置:', error.message);
        return this.config;
      }
      throw this._createError('CONFIG_ERROR', `无法加载配置: ${error.message}`);
    }
  }

  // ==================== HTTP核心方法 ====================

  /**
   * 发送HTTP请求（带重试和熔断）
   */
  async request(method, path, options = {}) {
    // 熔断器检查
    if (this.circuitState === 'OPEN') {
      if (Date.now() < this.circuitNextAttempt) {
        throw this._createError('CIRCUIT_BREAKER', '服务暂时不可用，请稍后重试');
      }
      this.circuitState = 'HALF_OPEN';
    }

    // 确保配置已加载
    if (!this.baseURL) {
      await this._loadConfig();
    }

    // 执行请求（带重试）
    let lastError;
    for (let attempt = 1; attempt <= this.retryConfig.maxAttempts; attempt++) {
      try {
        const result = await this._executeRequest(method, path, options);
        this._onRequestSuccess();
        return result;
      } catch (error) {
        lastError = error;
        
        // 判断是否应该重试
        if (!this._shouldRetry(error, attempt)) {
          this._onRequestFailure();
          throw error;
        }
        
        // 计算退避延迟
        const delay = this._calculateDelay(attempt);
        console.warn(`请求失败，${delay}ms后重试 (${attempt}/${this.retryConfig.maxAttempts})`);
        await this._sleep(delay);
      }
    }
    
    this._onRequestFailure();
    throw lastError;
  }

  /**
   * 执行单次请求
   */
  async _executeRequest(method, path, options) {
    const url = `${this.baseURL}${path}`;
    
    // 获取有效Token
    const token = await this._getValidToken();
    
    const config = {
      method,
      headers: {
        ...this.headers,
        ...(token && { 'Authorization': `Bearer ${token}` }),
        ...options.headers
      }
    };

    // 处理请求体
    if (options.body) {
      if (options.body instanceof FormData) {
        delete config.headers['Content-Type'];
        config.body = options.body;
      } else if (typeof options.body === 'object') {
        config.body = JSON.stringify(options.body);
      } else {
        config.body = options.body;
      }
    }

    // 应用请求拦截器
    for (const interceptor of this.requestInterceptors) {
      await interceptor(config, { url, method, path });
    }

    // 发送请求
    let response;
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), options.timeout || this.timeout);
      
      config.signal = controller.signal;
      response = await fetch(url, config);
      clearTimeout(timeoutId);
      
    } catch (error) {
      if (error.name === 'AbortError') {
        throw this._createError('TIMEOUT', `请求超时 (${options.timeout || this.timeout}ms)`, { timeout: options.timeout || this.timeout });
      }
      throw this._createError('NETWORK', `网络错误: ${error.message}`);
    }

    // 应用响应拦截器
    for (const interceptor of this.responseInterceptors) {
      await interceptor(response, { url, method, path });
    }

    return this._handleResponse(response);
  }

  /**
   * 处理响应
   */
  async _handleResponse(response) {
    // 204 No Content
    if (response.status === 204) {
      return null;
    }

    // 解析响应
    let data;
    const contentType = response.headers.get('content-type');
    
    try {
      if (contentType && contentType.includes('application/json')) {
        data = await response.json();
      } else {
        data = await response.text();
      }
    } catch (e) {
      data = null;
    }

    // 错误处理
    if (!response.ok) {
      // 认证错误
      if (response.status === 401) {
        this.token = null;
        throw this._createError('AUTH', data?.message || '认证失败，请重新登录', { status: 401, data });
      }
      
      // 权限错误
      if (response.status === 403) {
        throw this._createError('FORBIDDEN', data?.message || '没有权限执行此操作', { status: 403, data });
      }
      
      // 其他错误
      throw this._createError(
        data?.code || `HTTP_${response.status}`,
        data?.message || `HTTP ${response.status}: ${response.statusText}`,
        { status: response.status, data }
      );
    }

    return data;
  }

  // HTTP便捷方法
  async get(path, params, options = {}) {
    const query = params ? '?' + new URLSearchParams(params).toString() : '';
    return this.request('GET', path + query, options);
  }

  async post(path, body, options = {}) {
    return this.request('POST', path, { ...options, body });
  }

  async put(path, body, options = {}) {
    return this.request('PUT', path, { ...options, body });
  }

  async patch(path, body, options = {}) {
    return this.request('PATCH', path, { ...options, body });
  }

  async delete(path, options = {}) {
    return this.request('DELETE', path, options);
  }

  // ==================== Token管理 ====================

  /**
   * 获取有效Token
   */
  async _getValidToken() {
    if (!this.token) return null;
    
    // 检查是否即将过期
    if (this.tokenExpiresAt && Date.now() >= (this.tokenExpiresAt - this.tokenConfig.bufferTime)) {
      return this._refreshToken();
    }
    
    return this.token;
  }

  /**
   * 刷新Token
   */
  async _refreshToken() {
    if (this.refreshPromise) {
      return this.refreshPromise;
    }

    this.refreshPromise = this._doRefreshToken();
    
    try {
      const token = await this.refreshPromise;
      return token;
    } finally {
      this.refreshPromise = null;
    }
  }

  async _doRefreshToken() {
    if (!this.refreshToken) {
      throw this._createError('AUTH', '没有刷新令牌');
    }

    try {
      const response = await fetch(`${this.baseURL}${this.tokenConfig.refreshURL}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken: this.refreshToken })
      });

      if (!response.ok) {
        this.token = null;
        this.refreshToken = null;
        throw this._createError('AUTH', 'Token刷新失败，请重新登录');
      }

      const data = await response.json();
      this._setTokens({
        token: data.accessToken || data.token,
        refreshToken: data.refreshToken || this.refreshToken,
        expiresIn: data.expiresIn || 3600
      });

      return this.token;
    } catch (error) {
      this.token = null;
      throw error;
    }
  }

  _setTokens({ token, refreshToken, expiresIn }) {
    this.token = token;
    this.refreshToken = refreshToken;
    this.tokenExpiresAt = Date.now() + (expiresIn * 1000);
  }

  // ==================== 熔断器逻辑 ====================

  _onRequestSuccess() {
    this.failureCount = 0;
    if (this.circuitState === 'HALF_OPEN') {
      this.successCount++;
      if (this.successCount >= this.circuitSuccessThreshold) {
        this.circuitState = 'CLOSED';
        this.successCount = 0;
      }
    }
  }

  _onRequestFailure() {
    this.failureCount++;
    if (this.failureCount >= this.circuitFailureThreshold) {
      this.circuitState = 'OPEN';
      this.circuitNextAttempt = Date.now() + this.circuitTimeout;
    }
  }

  // ==================== 重试逻辑 ====================

  _shouldRetry(error, attempt) {
    if (attempt >= this.retryConfig.maxAttempts) return false;
    
    // 根据错误类型判断
    if (error.type === 'TIMEOUT') return true;
    if (error.type === 'NETWORK') return true;
    if (error.status && this.retryConfig.retryableStatuses.includes(error.status)) return true;
    
    return false;
  }

  _calculateDelay(attempt) {
    const exponential = this.retryConfig.baseDelay * Math.pow(2, attempt - 1);
    const jitter = exponential * 0.2 * Math.random();
    return Math.min(exponential + jitter, this.retryConfig.maxDelay);
  }

  // ==================== 错误处理 ====================

  _createError(type, message, details = {}) {
    const error = new Error(message);
    error.type = type;
    error.timestamp = new Date().toISOString();
    Object.assign(error, details);
    return error;
  }

  _sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  // ==================== 拦截器 ====================

  addRequestInterceptor(fn) {
    this.requestInterceptors.push(fn);
    return this;
  }

  addResponseInterceptor(fn) {
    this.responseInterceptors.push(fn);
    return this;
  }

  addErrorInterceptor(fn) {
    this.errorInterceptors.push(fn);
    return this;
  }

  // ==================== 认证API ====================

  async login(credentials) {
    const data = await this.post('/auth/login', credentials);
    this._setTokens({
      token: data.accessToken || data.token,
      refreshToken: data.refreshToken,
      expiresIn: data.expiresIn || 3600
    });
    return data;
  }

  async logout() {
    try {
      await this.post('/auth/logout');
    } finally {
      this.token = null;
      this.refreshToken = null;
    }
    return true;
  }

  // ==================== 内置API ====================

  async uploadFile(file, options = {}) {
    const formData = new FormData();
    formData.append('file', file);
    
    if (options.directory) {
      formData.append('directory', options.directory);
    }
    
    return this.post('/files/upload', formData, {
      headers: {} // 让浏览器自动设置Content-Type
    });
  }

  async downloadFile(fileId, filename) {
    const response = await this.request('GET', `/files/${fileId}/download`);
    const blob = await response.blob();
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename || 'download';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.URL.revokeObjectURL(url);
    return true;
  }

  async getFilePreviewUrl(fileId) {
    return this.get(`/files/${fileId}/preview`);
  }

  async deleteFile(fileId) {
    return this.delete(`/files/${fileId}`);
  }

  // =================== 业务API ===================

  // 用例模型直接定义的API
  <#list apiModel.usecases as usecase>
    <#assign paramObj = usecase.parameterizedObject>

  async ${js.nameVariable(usecase.name)}(params) {
    <#list paramObj.attributes as attr>
      <#if attr.constraint.nullable><#continue></#if>
      if (!params.${modelbase.get_attribute_sql_name(attr)} || params.${modelbase.get_attribute_sql_name(attr)} == null) {
        throw '';
      }
    </#list>
    return this.post(`/usecase/${java.nameVariable(usecase.name)}`, params);
  }
  </#list>

  // 数据模型隐式定义的API
  <#list dataModel.objects as obj>
    <#if modelbase.is_object_entity(obj)>
    <#elseif modelbase.is_object_value(obj)>
    </#if>
  </#list>
}

// ==================== 工厂函数 ====================

/**
 * 创建并初始化Remote实例
 */
async function createRemote(options = {}) {
  const api = new Remote(options);
  await api.init();
  return api;
}

// ====================== 导出 =====================

const sdk = createRemote();

export { sdk };

// CommonJS兼容
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { sk };
}
