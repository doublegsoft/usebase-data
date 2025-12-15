<#function name_method_return method>
  <#local strs = method?split(".")>
  <#local meth = "">
  <#if strs?size == 1>
    <#local meth = strs[0]>
  <#elseif strs?size == 2>
    <#local meth = strs[1]> 
  </#if>
  <#local ret = "">
  <#local strs = meth?split("_")>
  <#list strs as str>
    <#if str?index == 0><#continue></#if>
    <#if str?index != 1>
      <#local ret += java.nameType(str)>
    <#else>
      <#local ret += str> 
    </#if>
  </#list>
  <#return ret>
</#function>
