<#import "/$/modelbase.ftl" as modelbase />
<#import "/$/usebase.ftl" as usebase />
<#import "/$/modelbase4java.ftl" as modelbase4java />
<#import "/$/usebase4java.ftl" as usebase4java />
<#if license??>
${java.license(license)}
</#if>
<#assign paramObj = usecase.parameterizedObject>
<#assign isArray = "false">
<#if usecase.returnedObject??>
  <#assign retObj = usecase.returnedObject>
  <#assign isArray = retObj.getLabelledOption("original", "array")!"false">
</#if>
package ${namespace}.${java.nameType(app.name)?lower_case}.service.impl;

import java.util.List;
import java.util.ArrayList;
import java.util.Date;
import java.util.Map;
import java.util.Set;
import java.util.HashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import <#if namespace??>${namespace}.</#if>${app.name}.dto.payload.*;
import <#if namespace??>${namespace}.</#if>${app.name}.dto.info.*;
import <#if namespace??>${namespace}.</#if>${app.name}.dto.msg.*;
import ${namespace}.${java.nameType(app.name)?lower_case}.service.*;
import ${namespace}.${java.nameType(app.name)?lower_case}.util.*;

public class ${java.nameType(usecase.name)}ServiceImpl implements ${java.nameType(usecase.name)}Service {
  
  private static final Logger TRACER = LoggerFactory.getLogger(${java.nameType(usecase.name)}ServiceImpl.class);

<#assign aggregateChain = aggregateBuilder.build(retObj)>
<#assign objRelsList = aggregateChain.build()>
<#list aggregateChain.getObjects() as obj>

  private ${java.nameType(obj.name)}Service ${java.nameVariable(obj.name)}Service;
</#list>

<#if isArray == "true">
  public List<${java.nameType(usecase.name)}Result> ${java.nameVariable(usecase.name)}(${java.nameType(usecase.name)}Params params) throws ServiceException {
<#else>
  public ${java.nameType(usecase.name)}Result ${java.nameVariable(usecase.name)}(${java.nameType(usecase.name)}Params params) throws ServiceException {
</#if>    
    TRACER.info("${java.nameVariable(usecase.name)} entered with {}.", params);
<#if isArray == "true">
    List<${java.nameType(usecase.name)}Result> retVal = new ArrayList<>();
<#else>
    ${java.nameType(usecase.name)}Result retVal = new ${java.nameType(usecase.name)}Result();
</#if>    
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
<#-- 声明所有参数对象的属性，并且赋值 -->
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
        !existing${java.nameType(uniqueObjName)}.get${java.nameType(modelbase.get_attribute_sql_name(uniqueObjIdAttr))}().equals(${modelbase.get_attribute_sql_name(uniqueObjIdAttr)})) {
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
<#assign retObjs = {}>
<#if usecase.returnedObject??>
  <#assign retObj = usecase.returnedObject>
  <#if retObj.array>  
    <#----------------------->
    <#-- 拼接各个查询结果集合 -->
    <#----------------------->
    <#list retObj.attributes as attr>
      <#assign origObjName = attr.getLabelledOption("original", "object")!"">
      <#assign opname = attr.getLabelledOption("original", "operator")!"">
      <#if origObjName != "" && !retObjs[origObjName]?? && opname == "">
        <#assign origObj = model.findObjectByName(origObjName)>
        <#assign origObjIdAttr = modelbase.get_id_attributes(origObj)?first>
        <#assign retObjs += {origObjName:origObjName}>
        <#if attr.getLabelledOption("conjunction", "target_attribute")??>
          <#assign targetObjName = attr.getLabelledOption("conjunction", "target_object")>
          <#assign targetAttrName = attr.getLabelledOption("conjunction", "target_attribute")>
          <#assign sourceObjName = attr.getLabelledOption("conjunction", "source_object")>
          <#assign sourceAttrName = attr.getLabelledOption("conjunction", "source_attribute")>
          <#assign targetObj = model.findObjectByName(targetObjName)>
          <#assign targetObjAttr = targetObj.getAttribute(targetAttrName)>
          <#assign sourceObj = model.findObjectByName(sourceObjName)>
          <#assign sourceObjAttr = sourceObj.getAttribute(sourceAttrName)>
    Map<${modelbase4java.type_attribute_primitive(origObjIdAttr)}, ${java.nameType(sourceObj.name)}Query> ${java.nameVariable(sourceObj.name)}QueryIndexes = new HashMap<>();       
    for (${java.nameType(origObjName)}Query row : ${java.nameVariable(inflector.pluralize(origObjName))}) {
      ${java.nameVariable(sourceObj.name)}QueryIndexes.put(row.get${java.nameType(modelbase.get_attribute_sql_name(origObjIdAttr))}(), row);
    }
        </#if>   
      <#elseif origObjName == "" || opname != "">
    for (Map<String,Object> row : ${java.nameVariable(inflector.pluralize(attr.name))}) {
      Integer idx = idIndexes.get(row.get${java.nameType(modelbase.get_attribute_sql_name(origObjIdAttr))}());
      if (idx == null) {
        continue;
      }
      ${java.nameType(usecase.name)}Result result = retVal.get(idx);
      if (result == null) {
        continue;
      }
      result.set${java.nameType(attr.name)}((${modelbase4java.type_attribute(attr)})row.get("${java.nameVariable(attr.name)}"));
    }
      </#if>  
    </#list>
    <#-- FIXME: 不是非常严谨 -->
    <#assign masterObjAttr = retObj.attributes?first>
    <#assign origObjName = masterObjAttr.getLabelledOption("original", "object")!"">
    <#assign origObj = model.findObjectByName(origObjName)>
    <#assign origObjIdAttr = modelbase.get_id_attributes(origObj)?first>
    <#assign joinedObjAttrs = {(origObjName + "#" + origObjIdAttr.name): origObj}>
    for (${java.nameType(origObjName)}Query row : ${java.nameVariable(inflector.pluralize(origObjName))}) {
      ${java.nameType(usecase.name)}Result result = new ${java.nameType(usecase.name)}Result();
      result.copyFrom${java.nameType(origObjName)}(row);
      retVal.add(result);
    <#list retObj.attributes as attr>
      <#if !attr.isLabelled("original")><#continue></#if>
      <#assign origObjName = attr.getLabelledOption("original", "object")>
      <#assign origAttrName = attr.getLabelledOption("original", "attribute")>
      <#if joinedObjAttrs[(origObjName + "#" + origAttrName)]??><#continue></#if>
      <#if attr.getLabelledOption("conjunction", "target_attribute")??>
        <#assign targetObjName = attr.getLabelledOption("conjunction", "target_object")>
        <#assign targetAttrName = attr.getLabelledOption("conjunction", "target_attribute")>
        <#assign sourceObjName = attr.getLabelledOption("conjunction", "source_object")>
        <#assign sourceAttrName = attr.getLabelledOption("conjunction", "source_attribute")>
        <#if joinedObjAttrs[(sourceObjName + "#" + sourceAttrName)]??><#continue></#if>
        <#assign targetObj = model.findObjectByName(targetObjName)>
        <#assign targetObjAttr = targetObj.getAttribute(targetAttrName)>
        <#assign sourceObj = model.findObjectByName(sourceObjName)>
        <#assign sourceObjAttr = sourceObj.getAttribute(sourceAttrName)>
        <#assign joinedObjAttrs += {(sourceObjName + "#" + sourceAttrName): sourceObj}>
      ${java.nameType(sourceObj.name)}Query found${java.nameType(sourceObj.name)} = ${java.nameVariable(sourceObj.name)}QueryIndexes.get(row.get${java.nameType(modelbase.get_attribute_sql_name(targetObjAttr))}());
      if (found${java.nameType(sourceObj.name)} != null) {
        result.copyFrom${java.nameType(origObjName)}(found${java.nameType(sourceObj.name)});
      }
      </#if>  
    </#list>
    }
  <#else>
    <#list retObj.attributes as attr>
      <#assign origobj = attr.getLabelledOption("original", "object")!"">
      <#assign opname = attr.getLabelledOption("original", "operator")!"">
      <#if origobj != "" && !retObjs[origobj]?? && opname == "">
        <#assign retObjs += {origobj:origobj}>
    retVal.copyFrom${java.nameType(origobj)}(${java.nameVariable(origobj)});
      <#elseif origobj == "" || opname != "">
    retVal.copyFrom${java.nameType(attr.name)}(${java.nameVariable(attr.name)});
      </#if>
    </#list>
  </#if><#--if retObj.array-->  
</#if>
    TRACER.info("${java.nameVariable(usecase.name)} exited with {}.", retVal);
    return retVal;
  }
  
}