<#import "/$/modelbase.ftl" as modelbase />
<#import "/$/modelbase4java.ftl" as modelbase4java />
<#import "/$/usebase4java.ftl" as usebase4java />
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
<#-- 列举参数对象中所有的对象及其标识字段 -->    
<#assign explicitIdAttrs = {}>
<#assign explicitObjNames = {}>
<#list paramObj.attributes as attr>
  <#if attr.type.collection><#continue></#if>
  <#assign originalObjName = attr.getLabelledOption("original", "object")!"">
  <#if originalObjName != "" && !explicitObjNames[originalObjName]??>
    <#assign explicitObjNames = explicitObjNames + {originalObjName: true}>
    <#assign originalObj = model.findObjectByName(originalObjName)>
    <#assign originalIdAttrs = modelbase.get_id_attributes(originalObj)>
    <#list originalIdAttrs as idAttr>
      <#assign explicitIdAttrs = explicitIdAttrs + {modelbase.get_attribute_sql_name(idAttr): idAttr}>
    </#list>
  </#if>
</#list>  
<#-- 潜在对象的所有标识字段，列举出来，不需要赋值 -->
<#list explicitIdAttrs?values as idAttr>
    ${modelbase4java.type_attribute_primitive(idAttr)} ${modelbase.get_attribute_sql_name(idAttr)} = null;
</#list>
<#-- 列举所有参数对象的属性，并且赋值 -->
<#list paramObj.attributes as attr>
  <#if explicitIdAttrs[modelbase.get_attribute_sql_name(attr)]??>
    <#assign assignedIdAttr = attr>
    ${java.nameVariable(attr.name)} = params.get${java.nameType(attr.name)}();
  <#else>
    ${modelbase4java.type_attribute(attr)} ${java.nameVariable(attr.name)} = params.get${java.nameType(attr.name)}();
  </#if>  
</#list>
<#-- 对潜在对象的标识字段赋值 -->
<#if assignedIdAttr??>
  <#list explicitIdAttrs?values as idAttr>
    <#if modelbase.get_attribute_sql_name(idAttr) != modelbase.get_attribute_sql_name(assignedIdAttr)>
    ${modelbase.get_attribute_sql_name(idAttr)} = ${modelbase.get_attribute_sql_name(assignedIdAttr)};
    </#if> 
  </#list>
</#if>   
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
      throw new ServiceException("${modelbase.get_object_label(uniqueObj)}已经存在，不能重复创建");
    }
</#if>
<#list usecase.statements as stmt>
<@usebase4java.print_statement usecase=usecase stmt=stmt indent=4 />  
</#list>
    ${java.nameType(usecase.name)}Result retVal = new ${java.nameType(usecase.name)}Result();
    return retVal;
  }
  
}