<#import "/$/modelbase.ftl" as modelbase>
<#import "/$/modelbase4java.ftl" as modelbase4java>
<#if license??>
${java.license(license)}
</#if>
package ${namespace}.${app.name}.service.dto;

import java.io.Serializable;
import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Date;
import java.util.HashMap;
import java.util.ArrayList;

/*!
** 【${modelbase.get_object_label(obj)}】
*/
public class ${java.nameType(obj.name)} implements Serializable {

  private static long serialVersionNumber = -1L;

<#list obj.attributes as attr>

  /**
  * 【${modelbase.get_attribute_label(attr)}】
  */
  private ${modelbase4java.type_attribute(attr)} ${java.nameVariable(modelbase.get_attribute_sql_name(attr))};
</#list>
<#list obj.attributes as attr>

  public ${modelbase4java.type_attribute(attr)} get${java.nameType(modelbase.get_attribute_sql_name(attr))}() {
    return ${java.nameVariable(modelbase.get_attribute_sql_name(attr))};
  }

  public void set${java.nameType(modelbase.get_attribute_sql_name(attr))}(${modelbase4java.type_attribute(attr)} ${java.nameVariable(modelbase.get_attribute_sql_name(attr))}) {
    this.${java.nameVariable(modelbase.get_attribute_sql_name(attr))} = ${java.nameVariable(modelbase.get_attribute_sql_name(attr))};
  }
</#list>
}