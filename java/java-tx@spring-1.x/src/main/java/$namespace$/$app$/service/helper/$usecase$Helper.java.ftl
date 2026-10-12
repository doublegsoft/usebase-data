<#import "/$/modelbase.ftl" as modelbase />
<#import "/$/usebase.ftl" as usebase />
<#import "/$/modelbase4java.ftl" as modelbase4java />
<#import "/$/usebase4java.ftl" as usebase4java />
<#if license??>
${java.license(license)}
</#if>
package ${namespace}.${java.nameType(app.name)?lower_case}.service.helper;

import java.sql.Timestamp;
import java.util.*;
import jakarta.inject.Named;  

import <#if namespace??>${namespace}.</#if>${app.name}.dto.payload.*;

@Named
public class ${java.nameType(usecase.name)}Helper {
<#list usecase.invocations as invo>

  <#if invo.returnType??>
  public ${usebase4java.type_variable(usecase, invo.returnType)} ${java.nameVariable(invo.method)}(<#list invo.arguments as arg><#if arg?index != 0>,</#if>${usebase4java.type_variable(usecase, arg.name)} ${java.nameVariable(arg.name)}</#list>) {      
    return null;
  }  
  <#else>
  public void ${java.nameVariable(invo.method)}(<#list invo.arguments as arg><#if arg?index != 0>,</#if>${usebase4java.type_variable(usecase, arg.name)} ${java.nameVariable(arg.name)}</#list>) {      

  }  
  </#if>
</#list> 
}