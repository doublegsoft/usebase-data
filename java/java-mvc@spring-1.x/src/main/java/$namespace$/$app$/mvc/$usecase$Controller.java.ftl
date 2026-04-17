<#import "/$/modelbase.ftl" as modelbase />
<#import "/$/usebase.ftl" as usebase />
<#import "/$/modelbase4java.ftl" as modelbase4java />
<#import "/$/usebase4java.ftl" as usebase4java />
<#if license??>
${java.license(license)}
</#if>
<#assign paramObj = usecase.getParameterizedObject()>
<#if usecase.getReturnedObject()??>
  <#assign retObj = usecase.getReturnedObject()>
</#if>
package <#if namespace??>${namespace}.</#if>${app.name?lower_case}.mvc;

import java.util.List;
import java.util.ArrayList;
import java.util.Map;
import java.util.HashMap;
import java.math.BigDecimal;
import java.io.Serializable;
import java.sql.Date;
import java.sql.Timestamp;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Named;  
import jakarta.inject.Inject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.*;
import org.springframework.transaction.annotation.*;
import org.springframework.stereotype.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.MediaType;

import <#if namespace??>${namespace}.</#if>${app.name}.poco.*;
import <#if namespace??>${namespace}.</#if>${app.name}.orm.assembler.*;
import <#if namespace??>${namespace}.</#if>${app.name}.dto.payload.*;
import <#if namespace??>${namespace}.</#if>${app.name}.dto.msg.*;
import <#if namespace??>${namespace}.</#if>${app.name}.service.*;

/**
 * 【${usecase.name}】控制器。
 */
@RestController("<#if namespace??>${namespace}.</#if>${app.name}.mvc.${java.nameType(usecase.name)}Controller") 
@RequestMapping("/${app.name}")
public class ${java.nameType(usecase.name)}Controller extends BaseController {

  private static final Logger TRACER = LoggerFactory.getLogger(${java.nameType(usecase.name)}Controller.class);

  @Inject
  private ${java.nameType(usecase.name)}Service ${java.nameVariable(usecase.name)}Service;

  @PostMapping(value = "/${usecase.name}", produces = MediaType.APPLICATION_JSON_VALUE + ";charset=utf-8")
  public RestResult ${java.nameVariable(usecase.name)}(@RequestBody ${java.nameType(paramObj.name?substring(1))}Params params) {
    try {
<#if retObj??>
  <#if retObj.getLabelledOptions("original")["array"]??>
      List<${java.nameType(retObj.name?substring(1))}Result> results = ${java.nameVariable(usecase.name)}Service.${java.nameVariable(usecase.name)}(params);
      return new RestResult(results);
  <#else>
      ${java.nameType(retObj.name?substring(1))}Result result = ${java.nameVariable(usecase.name)}Service.${java.nameVariable(usecase.name)}(params);
      return new RestResult(result);
  </#if>
<#else>
      ${java.nameVariable(usecase.name)}Service.${java.nameVariable(usecase.name)}(params);
      return new RestResult();
</#if>      
    } catch (Throwable cause) {
      TRACER.error(cause.getMessage(), cause);
      return error(cause);
    }
  }

}  


