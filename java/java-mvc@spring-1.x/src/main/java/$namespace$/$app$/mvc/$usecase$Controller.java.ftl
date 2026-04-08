<#import "/$/modelbase.ftl" as modelbase />
<#import "/$/usebase.ftl" as usebase />
<#import "/$/modelbase4java.ftl" as modelbase4java />
<#import "/$/usebase4java.ftl" as usebase4java />
<#if license??>
${java.license(license)}
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
import <#if namespace??>${namespace}.</#if>${app.name}.service.*;

/**
 * 【${usecase.name}】控制器。
 */
@RestController("<#if namespace??>${namespace}.</#if>${app.name}.mvc.${java.nameType(usecase.name)}Controller") 
@RequestMapping("/${app.name}")
public class ${java.nameType(usecase.name)}Controller extends BaseController {

  @Inject
  private ${java.nameType(usecase.name)}Service ${java.nameVariable(usecase.name)}Service;

}  


