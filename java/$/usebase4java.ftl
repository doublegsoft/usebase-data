<#macro print_statement usecase stmt indent>
  <#if stmt.operator?ends_with("?|")>
<@print_statement_comparison usecase=usecase stmt=stmt indent=indent />  
  <#elseif stmt.operator?ends_with("+|")>
<@print_statement_save usecase=usecase stmt=stmt indent=indent />
  <#elseif stmt.operator?ends_with(":|")>
<@print_statement_assignment usecase=usecase stmt=stmt indent=indent />  
  <#elseif stmt.operator?ends_with("?|")>
<@print_statement_comparison usecase=usecase stmt=stmt indent=indent />  
  <#elseif stmt.operator?ends_with("@|")>
<@print_statement_invocation usecase=usecase stmt=stmt indent=indent />    
  </#if>
</#macro>

<#macro print_statement_comparison usecase stmt indent>
  <#if stmt.invocation??>
    <#local invoc = stmt.invocation>
${""?left_pad(indent)}try {
${""?left_pad(indent)}  ValidationResult res = ${invoc.method}(<#list invoc.arguments as arg><#if arg?index != 0>, </#if>${java.nameVariable(arg)}</#list>);
${""?left_pad(indent)}  if (!res.isSuccessful()) {
${""?left_pad(indent)}    throw new ServiceException("${invoc.error!"校验错误"}："<#list invoc.arguments as arg><#if arg?index != 0> + ", " </#if> + ${java.nameVariable(arg)}</#list>);
${""?left_pad(indent)}  }
${""?left_pad(indent)}} catch (RemoteException ex) {
${""?left_pad(indent)}  throw new ServiceException("远程调用失败", ex);
${""?left_pad(indent)}}
  </#if> 
</#macro>

<#macro print_statement_save usecase stmt indent>
  <#local save = stmt>
  <#if save.saveObject??>
    <#local saveObjName = save.saveObject.name?replace("#", "")>
    <#if saveObjName?starts_with("[]")>
      <#local saveObjName = saveObjName?replace("[]", "")>
${""?left_pad(indent)}${java.nameVariable(saveObjName)}Service.save${java.nameType(inflector.pluralize(saveObjName))}(${java.nameVariable(inflector.pluralize(saveObjName))});    
    <#else>
${""?left_pad(indent)}${java.nameVariable(saveObjName)}Service.save${java.nameType(saveObjName)}(${java.nameVariable(saveObjName)});
    </#if>
  </#if>
</#macro>

<#macro print_statement_assignment usecase stmt indent>
  <#local assign = stmt>
  <#if assign.assignOp == "=">
    <#if assign.value.invocation??>
${""?left_pad(indent)}${java.nameVariable(assign.assignee)} = ${assign.value.invocation.method}();
    <#elseif assign.value.objectValue??>
      <#local objVal = assign.value.objectValue>
      <#local uniqueObjName = objVal.getLabelledOption("unique", "object")>
      <#local uniqueAttrNames = objVal.getLabelledOptionAsList("unique", "attribute")>
${""?left_pad(indent)}${java.nameType(uniqueObjName)}Query unique${java.nameType(uniqueObjName)}Query = new ${java.nameType(uniqueObjName)}Query();
      <#list uniqueAttrNames as attrname>
        <#local uniqueAttr = apiModel.findAttributeByNames(objVal.name, attrname)>
        <#if uniqueAttr.alias??>
${""?left_pad(indent)}unique${java.nameType(uniqueObjName)}Query.set${java.nameType(uniqueAttr.alias)}(${java.nameVariable(attrname)});
        <#else>
${""?left_pad(indent)}unique${java.nameType(uniqueObjName)}Query.set${java.nameType(attrname)}(${java.nameVariable(attrname)});        
        </#if>
      </#list>
${""?left_pad(indent)}${java.nameVariable(assign.assignee)} = ${java.nameVariable(uniqueObjName)}Service.get${java.nameType(uniqueObjName)}(unique${java.nameType(uniqueObjName)}Query); 
      <#if objVal.isLabelled("required")>    
${""?left_pad(indent)}if (${java.nameVariable(assign.assignee)} == null) {
${""?left_pad(indent)}  throw new ServiceException("${objVal.getLabelledOption("required", "message")}")
${""?left_pad(indent)}}
      </#if>
    </#if>
  <#else>
  </#if>
</#macro>

<#macro print_statement_comparison usecase stmt indent>
  <#local cmp = stmt>
  <#if cmp.value?? && cmp.value.invocation??>
    <#local invo = cmp.value.invocation>
    <#if invo.error??>
      <#if cmp.comparator == '!='>
${""?left_pad(indent)}String ${usebase.name_method_return(invo.method)} = ${java.nameVariable(invo.method)}();      
${""?left_pad(indent)}if (!${cmp.comparand}.equals(${usebase.name_method_return(invo.method)})) {
${""?left_pad(indent)}  throw new ServiceException("${invo.error}");
${""?left_pad(indent)}}      
      </#if>
    </#if>
  </#if>
</#macro>

<#macro print_statement_invocation usecase stmt indent>
  <#local invo = stmt.invocation>
${""?left_pad(indent)}${java.nameVariable(invo.method)}(<#list invo.arguments as arg><#if arg?index != 0>,</#if>${java.nameVariable(arg)}</#list>);      
</#macro>