<#function name_method_return method>
  <#local strs = method?split(".")>
  <#local meth = "">
  <#if strs?size == 1>
    <#local meth = strs[0]>
  <#elseif strs?size == 2>
    <#local meth = strs[1]> 
  </#if>
  <#local ret = "">
  <#local strs = meth?split("_")>
  <#list strs as str>
    <#if str?index == 0><#continue></#if>
    <#if str?index != 1>
      <#local ret += java.nameType(str)>
    <#else>
      <#local ret += str> 
    </#if>
  </#list>
  <#return ret>
</#function>

<#-- 
 ### =========================================================================================
 ### Function: is_identifiable
 ### 
 ### 描述 (Description):
 ### 判断给定的属性（通常来自 DTO、Form 或 View Model）是否映射至底层领域实体的“主键/标识符”。
 ### 
 ### 核心逻辑 (Core Logic):
 ### 1. 检查映射标签 (Check Label): 
 ###    检查属性是否有 "original" 标签，这表示它映射自某个原始实体。
 ###
 ### 2. 解析原始信息 (Parse Source):
 ###    提取原始对象名 (objname) 和原始属性名 (attrname)。
 ###
 ### 3. 名称标准化 (Normalization):
 ###    执行特殊的命名清洗逻辑。例如，如果属性名为 "user_id" 且对象名为 "user"，
 ###    它会将其替换为 "id"。这是为了处理某些数据库命名约定带来的前缀。
 ###
 ### 4. 模型查找 (Model Lookup):
 ###    利用全局 model 对象，根据清洗后的名称找到真正的 AttributeDefinition 对象。
 ###
 ### 5. 身份检查 (Identity Check):
 ###    检查找到的原始属性是否具备 isIdentifiable() 特性 (即是否为主键)。
 ###
 ### @param attr - 需要检查的属性定义对象
 ### @return boolean - 如果是主键则返回 true，否则返回 false
 ### =========================================================================================
 -->
<#function is_identifiable attr>
  <#if attr.isLabelled("original")>
    <#local objname = attr.getLabelledOption("original", "object")!"">
    <#local attrname = attr.getLabelledOption("original", "attribute")!"">
    <#local attrname = attrname?replace(objname + "_","")>
    <#local attr = model.findAttributeByNames(objname, attrname)>
    <#if attr.identifiable>
      <#return true>
    </#if>
  </#if>
  <#return false>
</#function>

<#-- 
 ### =========================================================================================
 ### Function: group_attributes
 ### 
 ### 描述 (Description):
 ### 对对象的属性进行分组归类。主要用于 UI 生成阶段，例如将表单字段划分为不同的 Fieldset 或 Tab 页。
 ### 
 ### 分组逻辑 (Grouping Logic):
 ### 1. 标识符组 (_id):
 ###    首先调用 `is_identifiable` 函数。如果是主键/标识符属性，
 ###    会被收集到 key 为 "_id" 的列表中。这通常用于生成隐藏域 (Hidden Fields)。
 ###
 ### 2. 标签分组 (Labeled Groups):
 ###    检查属性是否包含 "group" 标签 (即 labelledOptions 中包含 group 配置)。
 ###    如果有，提取 group 的 name 选项，将属性添加到对应名称的列表中。
 ###    (例如: 属性标记为 group.name="BasicInfo"，则归入 "BasicInfo" 组)。
 ###
 ### 返回结构示例 (Return Structure):
 ### {
 ###   "_id": [Attribute(id)],
 ###   "BasicInfo": [Attribute(username), Attribute(email)],
 ###   "AuditInfo": [Attribute(createTime), Attribute(updateTime)]
 ### }
 ###
 ### @param obj - 包含属性定义的元数据对象 (ObjectDefinition)
 ### @return Hash<String, List<Attribute>> - Key为组名，Value为属性列表的映射表
 ### =========================================================================================
 -->
<#function group_unique_attributes obj>
  <#local ret = {}>
  <#list obj.attributes as attr>
    <#if is_identifiable(attr)>
      <#if !ret["_id"]??>
        <#local ret = ret + {"_id": []}>
      </#if>
      <#local arr = ret["_id"]>
      <#local arr = arr + [attr]>
      <#local ret = ret + {"_id": arr}>
    <#elseif attr.isLabelled("group")>
      <#local groupName = attr.getLabelledOption("group","name")!"">
      <#if ret[groupName]??>
        <#local ret = ret + {groupName: ret[groupName] + [attr]}>
      <#else>
        <#local ret = ret + {groupName: [attr]}>
      </#if>
    </#if>
  </#list>
  <#return ret>
</#function>

<#-- 
 ###
 ### Function: group_single_objects
 ### 
 ### 描述 (Description):
 ### 分析给定对象（通常是 DTO/ParamObject）的属性，提取出它所引用的所有唯一的、单数的领域对象定义。
 ### 
 ### 作用 (Purpose):
 ### 主要用于生成依赖注入代码。例如，一个 CompositeDTO 包含了 User 的 name 和 Department 的 title。
 ### 该函数会返回 [User, Department] 这两个对象定义。
 ### 这样模板就知道需要注入 @Autowired UserService and @Autowired DeptService。
 ### 
 ### 核心逻辑 (Core Logic):
 ### 1. 过滤集合 (Filter Collections): 忽略 List/Set 等集合属性，只关注 1:1 的引用。
 ### 2. 检查映射 (Check Mapping): 只处理标记了 "original" 的属性（即映射自领域模型的属性）。
 ### 3. 提取与去重 (Extract & Deduplicate): 
 ###    根据属性映射的 Object Name，在全局 Model 中查找对应的 ObjectDefinition。
 ###    使用 Map (ret) 进行去重，确保同一个领域对象只被返回一次。
 ### 
 ### @param obj - 需要分析的对象定义 (ObjectDefinition)
 ### @return Sequence<ObjectDefinition> - 引用的唯一领域对象列表
 ### =========================================================================================
 -->
<#function group_single_objects obj>
  <#local ret = {}>
  <#list obj.attributes as attr>
    <#if attr.type.collection><#continue></#if>
    <#if !attr.isLabelled("original")><#continue></#if>
    <#local objname = attr.getLabelledOption("original", "object")>
    <#local obj = model.findObjectByName(objname)>
    <#if !ret[objname]??>
      <#local ret = ret + {objname: obj}>
    </#if>
  </#list>
  <#return ret>
</#function>

<#function group_array_objects obj>
  <#local ret = {}>
  <#list obj.attributes as attr>
    <#if !attr.type.collection><#continue></#if>
    <#local conjObjName = attr.getLabelledOption("conjunction", "object")!"">
    <#local objname = attr.type.componentType.name>
    <#local obj = model.findObjectByName(objname)>
    <#if !ret[objname]??>
      <#local ret = ret + {objname: obj}>
    </#if>
    <#if conjObjName != "">
      <#local conjObj = model.findObjectByName(conjObjName)>
      <#if !ret[conjObjName]??>
        <#local ret = ret + {conjObjName: conjObj}>
      </#if>
    </#if>
  </#list>
  <#return ret>
</#function>

<#--
 ### Analyzes the relationships within a use case to identify all unique participating objects.
 ### <p>
 ### It prioritizes objects involved via identifiable attributes (primary keys) first,
 ### followed by objects involved via non-identifiable attributes. This ensures
 ### a deterministic order often required for correct SQL join generation or
 ### dependency injection.
 ###
 ### Note: order-sensitivity is important here for consistent behavior in downstream processing.
 ###
 ### @param aggregateObj
 ###        the aggregate object definition containing aggregation logic
 ###
 ### @return
 ###        a sequence of unique ObjectDefinition instances involved in the relationships
 -->
<#function group_relating_objects aggregateObj>
  <#local ret = []>
  <#local existingObjs = {}>
  <#local aggRels = aggregateBuilder.build(aggregateObj)>
  <#list aggRels.getRelationships() as rel>
    <#local sourceAttr = rel.getSourceAttribute()>
    <#local targetAttr = rel.getTargetAttribute()>
    <#local sourceKey = sourceAttr.parent.name>
    <#local targetKey = targetAttr.parent.name>
    <#if !existingObjs[sourceKey]?? && sourceAttr.identifiable>
      <#local ret = ret + [sourceAttr.parent]>
      <#local existingObjs = existingObjs + {sourceKey: true}>
    </#if>
    <#if !existingObjs[targetKey]?? && targetAttr.identifiable>
      <#local ret = ret + [targetAttr.parent]>
      <#local existingObjs = existingObjs + {targetKey: true}>  
    </#if>
  </#list>
  <#-- 漏网的对象，再次补充 -->
  <#list aggRels.getRelationships() as rel>
    <#local sourceAttr = rel.getSourceAttribute()>
    <#local targetAttr = rel.getTargetAttribute()>
    <#local sourceKey = sourceAttr.parent.name>
    <#local targetKey = targetAttr.parent.name>
    <#if !existingObjs[sourceKey]?? && !sourceAttr.identifiable>
      <#local ret = ret + [sourceAttr.parent]>
      <#local existingObjs = existingObjs + {sourceKey: true}>
    </#if>
    <#if !existingObjs[targetKey]?? && !targetAttr.identifiable>
      <#local ret = ret + [targetAttr.parent]>
      <#local existingObjs = existingObjs + {targetKey: true}>  
    </#if>
  </#list>
  <#return ret>  
</#function>

<#--
 ### Finds the referencing attribute (Foreign Key) that connects to the identifier
 ### of the specified target object within the use case's aggregation relationships.
 ### <p>
 ### This function iterates through the relationships built by the aggregateBuilder.
 ### It checks if the 'targetObj' is involved in a relationship via its identifiable
 ### attribute (Primary Key). If found, it returns the attribute from the other
 ### side of the relationship (Foreign Key).
 ###
 ### @param aggregateObj
 ###        the aggregate object definition containing the aggregation logic
 ### @param targetObj
 ###        the object definition acting as the referenced entity (typically the PK side)
 ###
 ### @return
 ###        the attribute definition that references the target object's ID
 -->
<#function get_relating_attribute aggregateObj targetObj>
  <#local aggRels = aggregateBuilder.build(aggregateObj)>
  <#list aggRels.getRelationships() as rel>
    <#local sourceAttr = rel.getSourceAttribute()>
    <#local targetAttr = rel.getTargetAttribute()>
    <#if sourceAttr.parent.name == targetObj.name && (sourceAttr.identifiable || targetAttr.identifiable)>
      <#return targetAttr>
    </#if>
    <#if targetAttr.parent.name == targetObj.name && (targetAttr.identifiable || sourceAttr.identifiable)>
      <#return sourceAttr>
    </#if>  
  </#list>
</#function>
