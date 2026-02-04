<#import "/$/modelbase.ftl" as modelbase>
<#import "/$/modelbase4java.ftl" as modelbase4java>
<#if license??>
${java.license(license)}
</#if>
<#assign obj = response>
<#assign idAttrs = modelbase.get_id_attributes(obj)>
package ${namespace}.${app.name}.dto.msg;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;
<#list modelbase4java.get_imports(obj)?sort as imp>
import ${imp};
</#list>
import ${namespace}.${app.name}.dto.info.*;
import ${namespace}.${app.name}.dto.payload.*;

/*!
** 【${modelbase.get_object_label(obj)}】
*/
public class ${java.nameType(obj.name)} implements Serializable {

  private static final long serialVersionUID = -1L;
<#list obj.attributes as attr>  

  /*!
  ** 【${modelbase.get_attribute_label(attr)}】
  */
  <#if attr.type.collection>
  protected final List<${java.nameType(attr.type.componentType.name)}> ${java.nameVariable(attr.name)} = new ArrayList<>();
  <#else>
  protected ${modelbase4java.type_attribute_primitive(attr)} ${java.nameVariable(attr.name)};
  </#if>
</#list>
<#list obj.attributes as attr>

  <#if attr.type.collection>
  public List<${java.nameType(attr.type.componentType.name)}> get${java.nameType(attr.name)}() {
    return ${java.nameVariable(attr.name)};
  }
  <#else>
  public ${modelbase4java.type_attribute_primitive(attr)} get${java.nameType(attr.name)}() {
    return ${java.nameVariable(attr.name)};
  }

  public void set${java.nameType(attr.name)}(${modelbase4java.type_attribute_primitive(attr)} ${java.nameVariable(attr.name)}) {
    this.${java.nameVariable(attr.name)} = ${java.nameVariable(attr.name)};
  }
  </#if>
</#list>
<#assign printedObjs = {}>
<#list obj.attributes as attr>
  <#if attr.type.collection>
    <#assign origObjInfo = attr.type.componentType.name>
    <#assign origObjName = origObjInfo?replace("info","query")>
    <#assign infoObj = model.findObjectByName(origObjInfo)>

  public void copyFrom${java.nameType(attr.name)}(List<${java.nameType(origObjName)}> ${java.nameVariable(attr.name)}) {
    for (${java.nameType(origObjName)} query : ${java.nameVariable(attr.name)}) {
      ${java.nameType(origObjInfo)} info = new ${java.nameType(origObjInfo)}();  
    <#list infoObj.attributes as infoAttr>  
      <#if (infoAttr.getLabelledOptions("original")["object"]!"") == origObjName?replace("_query","")>
      info.set${java.nameType(infoAttr.name)}(query.get${java.nameType(infoAttr.name)}());
      </#if>
    </#list>
      this.${java.nameVariable(attr.name)}.add(info);
    }
  }  
  <#elseif attr.isLabelled("original")>
    <#assign origObjName = attr.getLabelledOptions("original")["object"]>
    <#if !printedObjs[origObjName]??>

  public void copyFrom${java.nameType(origObjName)}(${java.nameType(origObjName)}Query ${java.nameVariable(origObjName)}) {
    // TODO
  }    
    </#if>
    <#assign printedObjs += {origObjName:origObjName}>
  </#if>
</#list>
}