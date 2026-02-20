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
<#----------------------->
<#-- 返回值需要的服务对象 -->
<#----------------------->
<#assign printedObjs = {}>
<#assign aggregateChain = aggregateBuilder.build(retObj)>
<#assign objRelsList = aggregateChain.build()>
<#list aggregateChain.getObjects() as obj>
  <#if printedObjs[obj.name]??><#continue></#if>
  <#assign printedObjs += {obj.name:obj.name}>

  private ${java.nameType(obj.name)}Service ${java.nameVariable(obj.name)}Service;
</#list>
<#---------------------------------->
<#-- 参数和返回值关联对象需要的服务对象 -->
<#---------------------------------->
<#assign associationChain = associationBuilder.build(paramObj, retObj)>
<#assign objSize = associationChain.getAssociatingObjects()?size>
<#if (objSize > 2)>
<#list 1..(objSize-2) as index>
  <#assign obj = associationChain.getAssociatingObjects()[index]>
  <#if printedObjs[obj.name]??><#continue></#if>
  <#assign printedObjs += {obj.name:obj.name}>

  private ${java.nameType(obj.name)}Service ${java.nameVariable(obj.name)}Service;
</#list>
</#if>
<#----------------------->
<#-- 从参数推导的服务对象 -->
<#----------------------->
<#list paramObj.attributes as attr>
  <#if !attr.isLabelled("original")><#continue></#if>
  <#assign objname = attr.getLabelledOption("original", "object")!"">
  <#if objname == "" || printedObjs[objname]??><#continue></#if>
  <#assign printedObjs += {objname:objname}>

  private ${java.nameType(objname)}Service ${java.nameVariable(objname)}Service;
</#list>
<#------------------------------->
<#-- 显式的方法逻辑中用到的服务对象 -->
<#------------------------------->
<#assign objsInStmts = usebase.get_objects_from_statements(usecase)>
<#list objsInStmts as objInData>
  <#if printedObjs[objInData.name]??><#continue></#if>
  <#assign printedObjs += {objInData.name:objInData}>

  private ${java.nameType(objInData.name)}Service ${java.nameVariable(objInData.name)}Service;    
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
      throw new ServiceException(404, "${modelbase.get_attribute_label(attr)}是必要参数，不能为空值");
    }
  </#if>
</#list>
<#------------------>
<#-- 数据唯一性校验 -->
<#------------------>
<#if paramObj.getLabelledOption("unique", "object")??>
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
      throw new ServiceException(403, "${modelbase.get_object_label(uniqueObj)}已经存在，不能重复创建");
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
        <#--
         ### 处理来自原始对象的属性（非计算字段）                                 
         ###                                                     
         ### 三个必要条件（AND关系）：                                
         ### 1. origObjName != "" : 该属性有明确的原始对象来源          
         ### 2. !retObjs[origObjName]?? : 该原始对象还未被处理过（防重复）
         ### 3. opname == "" : 不是操作符生成的字段（是直接映射字段）       
         ###                                                         
         ### 典型场景：                                             
         ### - 查询用户列表时，每个用户关联一个部门对象              
         ### - 查询订单列表时，每个订单关联多个订单项对象            
         ### - 查询文章列表时，每个文章关联一个作者对象             
         -->
        <#assign origObj = model.findObjectByName(origObjName)>
        <#assign origObjIdAttr = modelbase.get_id_attributes(origObj)?first>
        <#assign retObjs += {origObjName:origObjName}>
        <#if attr.getLabelledOption("conjunction", "target_attribute")??>
          <#assign attrConj = usebase.get_attribute_conjunction(attr)>
    Map<${modelbase4java.type_attribute_primitive(origObjIdAttr)}, ${java.nameType(attrConj.sourceObjName)}Query> ${java.nameVariable(attrConj.sourceObjName)}QueryIndexes = new HashMap<>();       
    for (${java.nameType(origObjName)}Query row : ${java.nameVariable(inflector.pluralize(origObjName))}) {
      ${java.nameVariable(attrConj.sourceObjName)}QueryIndexes.put(row.get${java.nameType(modelbase.get_attribute_sql_name(origObjIdAttr))}(), row);
    }
        </#if>   
      <#elseif origObjName == "" || opname != "">
        <#--
         ### 处理计算字段或自定义操作的结果拼接
         ### 
         ### 触发条件：
         ### 1. origObjName == "" : 该属性不是从某个原始对象直接映射来的
         ### 2. opname != "" : 该属性是通过某种操作(如聚合函数、计算表达式)得到的
         ### 
         ### 应用场景：
         ### - 聚合统计：如 count(*)、sum(amount)、avg(score) 等
         ### - 计算字段：如 price * quantity、concat(first_name, last_name) 等
         ### - 自定义函数：如 custom_func(field1, field2) 等
         ### 
         ### 处理逻辑：
         ### 这些计算字段的数据结构是 List<Map<String,Object>>，需要：
         ### 1. 遍历每一行计算结果
         ### 2. 通过ID找到对应的主结果对象
         ### 3. 将计算值设置到该结果对象的对应属性中
         -->
    // 拼接计算字段 ${attr.name} 到结果集
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
    <#------------------------------------------->
    <#-- 返回对象的第一个属性的原始对象作为【主对象】 -->
    <#------------------------------------------->
    <#assign masterObjAttr = retObj.attributes?first>
    <#assign masterObjName = (retObj.attributes?first).getLabelledOption("original", "object")!"">
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
      <#-- 首要对象需要忽略掉，应为链接其他对象的算法就在首要对象的循环体中 -->
      <#if origObjName == masterObjName><#continue></#if>
      <#if joinedObjAttrs[(origObjName + "#" + origAttrName)]??><#continue></#if>
      <#-- 判断属性是否定义连接 -->
      <#if attr.getLabelledOption("conjunction", "target_attribute")??>
        <#assign attrConj = usebase.get_attribute_conjunction(attr)>
        <#if joinedObjAttrs[(attrConj.sourceObjName + "#" + attrConj.sourceAttrName)]??><#continue></#if>
        <#assign joinedObjAttrs += {(attrConj.sourceObjName + "#" + attrConj.sourceAttrName): attrConj.sourceObj}>
      ${java.nameType(attrConj.sourceObjName)}Query found${java.nameType(attrConj.sourceObjName)} = ${java.nameVariable(attrConj.sourceObjName)}QueryIndexes.get(row.get${java.nameType(modelbase.get_attribute_sql_name(attrConj.targetAttr))}());
      if (found${java.nameType(attrConj.sourceObjName)} != null) {
        result.copyFrom${java.nameType(origObjName)}(found${java.nameType(attrConj.sourceObjName)});
      }
      </#if>  
    </#list>
    }
  <#else>
    <#---------------------------------------------------->
    <#-- 逐个拼接（Copy-From）单个对象的查询结果，单个或者集合 -->
    <#---------------------------------------------------->
    <#list retObj.attributes as attr>
      <#assign origobj = attr.getLabelledOption("original", "object")!"">
      <#assign opname = attr.getLabelledOption("original", "operator")!"">
      <#if origobj != "" && !retObjs[origobj]?? && opname == "">
        <#assign retObjs += {origobj:origobj}>
        <#if attr.type.collection>
    retVal.copyFrom${java.nameType(inflector.pluralize(origobj))}(${java.nameVariable(inflector.pluralize(origobj))});    
        <#else>
    retVal.copyFrom${java.nameType(origobj)}(${java.nameVariable(origobj)});
        </#if>
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