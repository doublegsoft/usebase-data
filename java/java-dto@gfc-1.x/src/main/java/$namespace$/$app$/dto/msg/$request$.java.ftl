<#import "/$/modelbase.ftl" as modelbase>
<#import "/$/modelbase4java.ftl" as modelbase4java>
<#if license??>
${java.license(license)}
</#if>
<#assign obj = request>
<#assign idAttrs = modelbase.get_id_attributes(obj)>
package ${namespace}.${app.name}.dto.msg;

import java.io.Serializable;
import java.util.ArrayList;
<#list modelbase4java.get_imports(obj)?sort as imp>
import ${imp};
</#list>
import ${namespace}.${app.name}.dto.info.*;

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
  protected List<${java.nameType(attr.type.componentType.name)}> ${java.nameVariable(attr.name)};
  <#else>
  protected ${modelbase4java.type_attribute_primitive(attr)} ${java.nameVariable(attr.name)};
  </#if>
</#list>
<#list obj.attributes as attr>  
 
  <#if attr.type.collection>
  public List<${java.nameType(attr.type.componentType.name)}> get${java.nameType(attr.name)}() {
    return ${java.nameVariable(attr.name)};
  }

  public void set${java.nameType(attr.name)}(List<${java.nameType(attr.type.componentType.name)}> ${java.nameVariable(attr.name)}) {
    this.${java.nameVariable(attr.name)} = ${java.nameVariable(attr.name)};
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
}