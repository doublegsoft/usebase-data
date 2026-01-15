<#if license??>
${java.license(license)}
</#if>
package ${namespace}.${java.nameType(app.name)?lower_case}.service;

import ${namespace}.${java.nameType(app.name)?lower_case}.dto.msg.*;

public interface ${java.nameType(usecase.name)}Service {
  
  /**
   *
   */
  ${java.nameType(usecase.name)}Result ${java.nameVariable(usecase.name)}(${java.nameType(usecase.name)}Params params) throws ServiceException;

}