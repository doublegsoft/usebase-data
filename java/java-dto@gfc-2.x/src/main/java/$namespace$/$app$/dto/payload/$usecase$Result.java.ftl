<#import "/$/modelbase.ftl" as modelbase>
<#import "/$/modelbase4java.ftl" as modelbase4java>
<#if license??>
${java.license(license)}
</#if>
package ${namespace}.${app.name}.dto.payload;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;
import java.util.Collections;
import java.util.Date;
import java.math.BigDecimal;

/*!
** 
*/
public class ${java.nameType(usecase.name)}Result implements Serializable {

  private static final long serialVersionUID = -1L;
<#if usecase.returnedObject??>
  <#list usecase.returnedObject.attributes as attr>
    <#assign origObjName = attr.getLabelledOptions("original")["object"]!"">
    <#assign origAttrName = attr.getLabelledOptions("original")["attribute"]!"">
    <#if origObjName != "">
      <#if attr.type.collection>
      
  private List<${java.nameType(origObjName)}Query> ${java.nameVariable(attr.name)} = new ArrayList<>();
      <#else>

  private ${modelbase4java.type_attribute_primitive(attr)} ${java.nameVariable(attr.name)};
      </#if>
    <#else>
  
  private ${modelbase4java.type_attribute_primitive(attr)} ${java.nameVariable(attr.name)};
    </#if>
  </#list>
</#if>
<#if usecase.returnedObject??>
  <#assign alreadyCopiedObjs = {}>
  <#list usecase.returnedObject.attributes as attr>
    <#assign origObjName = attr.getLabelledOptions("original")["object"]!"">
    <#assign origAttrName = attr.getLabelledOptions("original")["attribute"]!"">
    <#if origObjName != "" && !alreadyCopiedObjs[origObjName]??>
      <#assign alreadyCopiedObjs += { origObjName: true }>
      <#if attr.type.collection>

  public List<${java.nameType(origObjName)}Query> get${java.nameType(attr.name)}() {
    if (${java.nameVariable(attr.name)} == null) {
      return Collections.emptyList();
    }
    return ${java.nameVariable(attr.name)};
  }

  public void set${java.nameType(attr.name)}(List<${java.nameType(origObjName)}Query> ${java.nameVariable(attr.name)}) {
    this.${java.nameVariable(attr.name)} = ${java.nameVariable(attr.name)};
  }
      <#else>

  public void copyFrom${java.nameType(origObjName)}(${java.nameType(origObjName)}Query ${java.nameVariable(origObjName)}) {
        <#list usecase.returnedObject.attributes as attr>
          <#assign origObjNameInner = attr.getLabelledOptions("original")["object"]!"">
          <#if origObjNameInner != origObjName><#continue></#if>
          <#assign origAttrNameInner = attr.getLabelledOptions("original")["attribute"]!"">
          <#assign origAttrInner = model.findAttributeByNames(origObjNameInner, origAttrNameInner)>
    this.${java.nameVariable(attr.name)} = ${java.nameVariable(origObjName)}.${modelbase4java.name_getter(origAttrInner)}();
        </#list>
  }
      </#if>
    </#if>
  </#list>
  <#list usecase.returnedObject.attributes as attr>
    <#assign origObjName = attr.getLabelledOptions("original")["object"]!"">
    <#assign origAttrName = attr.getLabelledOptions("original")["attribute"]!"">
    <#if origObjName != "" && !attr.type.collection>

  public ${modelbase4java.type_attribute_primitive(attr)} get${java.nameType(attr.name)}() {
    return ${java.nameVariable(attr.name)};
  }
    </#if>
  </#list>
</#if>
}