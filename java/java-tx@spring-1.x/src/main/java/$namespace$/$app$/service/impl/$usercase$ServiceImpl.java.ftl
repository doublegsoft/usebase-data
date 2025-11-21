<#import "/$/modelbase.ftl" as modelbase />
<#import "/$/modelbase4java.ftl" as modelbase4java />
<#if license??>
${java.license(license)}
</#if>
<#assign paramObj = usecase.parameterizedObject>
package ${namespace}.${java.nameType(app.name)?lower_case}.service.impl;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import ${namespace}.${java.nameType(app.name)?lower_case}.service.${java.nameType(usecase.name)}Service;

public class ${java.nameType(usecase.name)}ServiceImpl implements ${java.nameType(usecase.name)}Service {
  
  private static final Logger TRACER = LoggerFactory.getLogger(${java.nameType(usecase.name)}ServiceImpl.class);

  public ${java.nameType(usecase.name)}Result ${java.nameVariable(usecase.name)}(${java.nameType(usecase.name)}Params params) throws ServiceException {
<#list paramObj.attributes as attr>
    ${modelbase4java.type_attribute(attr)} ${java.nameVariable(attr.name)} = params.get${java.nameType(attr.name)}();
</#list>
<#list paramObj.attributes as attr>
  <#if !attr.constraint.nullable>
    if (Strings.isBlank(${java.nameVariable(attr.name)})) {
      throw new ServiceException("${modelbase.get_attribute_label(attr)}是必要参数，不能为空值");
    }
  </#if>
</#list>
<#if paramObj.isLabelled("unique")>
  <#assign uniqueObjName = paramObj.getLabelledOption("unique", "object")>
  <#assign uniqueObj = model.findObjectByName(uniqueObjName)>
  <#assign uniqueObjIdAttr = modelbase.get_id_attributes(uniqueObj)?first>
  <#assign uniqueAttrNames = paramObj.getLabelledOptionAsList("unique", "attribute")>
    ${java.nameType(uniqueObjName)}Query existing${java.nameType(uniqueObjName)} = ${java.nameVariable(uniqueObjName)}Service.findSingle${java.nameType(uniqueObjName)}By<#list uniqueAttrNames as uan><#if uan?index != 0>And</#if>${java.nameType(uan)}</#list>(<#list uniqueAttrNames as uan><#if uan?index != 0>, </#if>${java.nameVariable(uan)}</#list>);
    if (existing${java.nameType(uniqueObjName)} != null && 
        !existing${java.nameType(uniqueObjName)}.getId().equals(${modelbase.get_attribute_sql_name(uniqueObjIdAttr)})) {
      throw new ServiceException("${modelbase.get_object_label(uniqueObj)}已存在，不能重复创建");
    }
</#if>
    ${java.nameType(usecase.name)}Result retVal = new ${java.nameType(usecase.name)}Result();
    return retVal;
  }
  
}