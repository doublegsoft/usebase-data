<#import "/$/modelbase.ftl" as modelbase />
<#import "/$/usebase.ftl" as usebase />
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
    TRACER.info("${java.nameVariable(usecase.name)} entered with {}.", params);
<#----------------------------------------------------------------------->    
<#-- 列举参数对象中所有的对象及其标识字段，参数对象包含一个或多个对象的属性组合而成 -->
<#----------------------------------------------------------------------->    
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
<#------------------------------------------->
<#-- 潜在对象的所有标识字段，列举出来，不需要赋值 -->
<#------------------------------------------->
<#list explicitIdAttrs?values as idAttr>
    ${modelbase4java.type_attribute_primitive(idAttr)} ${modelbase.get_attribute_sql_name(idAttr)} = null;
</#list>
<#--------------------------------->
<#-- 列举所有参数对象的属性，并且赋值 -->
<#--------------------------------->
<#list paramObj.attributes as attr>
  <#if explicitIdAttrs[modelbase.get_attribute_sql_name(attr)]??>
    <#assign assignedIdAttr = attr>
    ${java.nameVariable(attr.name)} = params.get${java.nameType(attr.name)}();
  <#else>
    <#if attr.constraint.defaultValue??>
    ${modelbase4java.type_attribute(attr)} ${java.nameVariable(attr.name)} = "${attr.constraint.defaultValue}";
    <#else>
    ${modelbase4java.type_attribute(attr)} ${java.nameVariable(attr.name)} = params.get${java.nameType(attr.name)}();
    </#if>
  </#if>  
</#list>
<#-------------------------->
<#-- 对象标识字段（潜在）赋值 -->
<#-------------------------->
<#if assignedIdAttr??>
  <#list explicitIdAttrs?values as idAttr>
    <#if modelbase.get_attribute_sql_name(idAttr) != modelbase.get_attribute_sql_name(assignedIdAttr)>
    ${modelbase.get_attribute_sql_name(idAttr)} = ${modelbase.get_attribute_sql_name(assignedIdAttr)};
    </#if> 
  </#list>
</#if>   
<#---------------->
<#-- 必要字段校验 -->
<#---------------->
<#list paramObj.attributes as attr>
  <#if !attr.constraint.nullable>
    if (Strings.isBlank(${java.nameVariable(attr.name)})) {
      throw new ServiceException("${modelbase.get_attribute_label(attr)}是必要参数，不能为空值");
    }
  </#if>
</#list>
<#------------------>
<#-- 数据唯一性校验 -->
<#------------------>
<#if paramObj.isLabelled("unique")>
  <#assign uniqueObjName = paramObj.getLabelledOption("unique", "object")>
  <#assign uniqueObj = model.findObjectByName(uniqueObjName)>
  <#assign uniqueObjIdAttr = modelbase.get_id_attributes(uniqueObj)?first>
  <#assign uniqueAttrNames = paramObj.getLabelledOptionAsList("unique", "attribute")>
    ${java.nameType(uniqueObjName)}Query ${java.nameVariable(uniqueObjName)}Query = new ${java.nameType(uniqueObjName)}Query();
  <#list uniqueAttrNames as attrname>
    ${java.nameVariable(uniqueObjName)}Query.set${java.nameType(attrname)}(${java.nameVariable(attrname)});
  </#list>  
    ${java.nameType(uniqueObjName)}Query existing${java.nameType(uniqueObjName)} = ${java.nameVariable(uniqueObjName)}Service.get${java.nameType(uniqueObjName)}(${java.nameVariable(uniqueObjName)}Query);
    if (existing${java.nameType(uniqueObjName)} != null && 
        !existing${java.nameType(uniqueObjName)}.getId().equals(${modelbase.get_attribute_sql_name(uniqueObjIdAttr)})) {
      throw new ServiceException("${modelbase.get_object_label(uniqueObj)}已经存在，不能重复创建");
    }
</#if>
<#--------------------->
<#-- 处理【模式化】逻辑 -->
<#--------------------->
<#if usecase.statements?size == 0>
<@usebase4java.print_body usecase=usecase indent=4 />  
</#if>
<#--------------------->
<#-- 处理【自定义】逻辑 -->
<#--------------------->
<#list usecase.statements as stmt>
<@usebase4java.print_statement usecase=usecase stmt=stmt indent=4 />  
</#list>
<#--------------------->
<#-- 封装服务函数返回值 -->
<#--------------------->
    ${java.nameType(usecase.name)}Result retVal = new ${java.nameType(usecase.name)}Result();
<#assign retObjs = {}>
<#if usecase.returnedObject??>
  <#assign retObj = usecase.returnedObject>
  <#if retObj.array>  
    <#list retObj.attributes as attr>
      <#assign origobj = attr.getLabelledOption("original", "object")!"">
      <#assign opname = attr.getLabelledOption("original", "operator")!"">
      <#if origobj != "" && !retObjs[origobj]?? && opname == "">
        <#assign retObjs += {origobj:origobj}>
    retVal.join${java.nameType(inflector.pluralize(origobj))}(${java.nameVariable(inflector.pluralize(origobj))});      
      <#elseif origobj == "" || opname != "">
    retVal.join${java.nameType(inflector.pluralize(attr.name))}(${java.nameVariable(inflector.pluralize(attr.name))});
      </#if>  
    </#list>
  <#else>  
    <#list retObj.attributes as attr>
      <#assign origobj = attr.getLabelledOption("original", "object")!"">
      <#assign opname = attr.getLabelledOption("original", "operator")!"">
      <#if origobj != "" && !retObjs[origobj]?? && opname == "">
        <#assign retObjs += {origobj:origobj}>
    retVal.copyFrom${java.nameType(origobj)}(${java.nameVariable(origobj)});
      <#elseif origobj == "" || opname != "">
    retVal.set${java.nameType(attr.name)}(${java.nameVariable(attr.name)});
      </#if>
    </#list>
  </#if>
</#if>
    TRACER.info("${java.nameVariable(usecase.name)} exited with {}.", retVal);
    return retVal;
  }
  
}