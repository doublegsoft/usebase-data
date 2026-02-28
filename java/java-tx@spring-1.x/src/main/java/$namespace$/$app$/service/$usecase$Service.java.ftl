<#if license??>
${java.license(license)}
</#if>
<#assign isArray = "false">
<#if usecase.returnedObject??>
  <#assign retObj = usecase.returnedObject>
  <#assign isArray = retObj.getLabelledOption("original", "array")!"false">
</#if>
package ${namespace}.${java.nameType(app.name)?lower_case}.service;

import java.util.List;
import ${namespace}.${java.nameType(app.name)?lower_case}.dto.msg.*;

public interface ${java.nameType(usecase.name)}Service {
  
  /**
   *
   */
<#if isArray == "true">
  List<${java.nameType(usecase.name)}Result> ${java.nameVariable(usecase.name)}(${java.nameType(usecase.name)}Params params) throws ServiceException;
<#elseif usecase.returnedObject??>
  ${java.nameType(usecase.name)}Result ${java.nameVariable(usecase.name)}(${java.nameType(usecase.name)}Params params) throws ServiceException;
<#else>
  void ${java.nameVariable(usecase.name)}(${java.nameType(usecase.name)}Params params) throws ServiceException;
</#if>      

}