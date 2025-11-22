<#macro print_statement usecase stmt indent>
  <#if stmt.operator?ends_with("?|")>
<@print_statement_comparison usecase=usecase stmt=stmt indent=indent />  
  <#elseif stmt.operator?ends_with(":|")>
  </#if>
</#macro>

<#macro print_statement_comparison usecase stmt indent>
  <#if stmt.invocation??>
    <#assign invoc = stmt.invocation>
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