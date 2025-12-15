<#function type_variable usecase varname>
  <#if model.findObjectByName(varname)??>
    <#return java.nameType(varname)>
  </#if>
  <#if usecase.paramemterizedObject??>
    <#list usecase.parameterizedObject.attributes as attr>
      <#if attr.name == varname>
        <#local attrVar = attr>
        <#break>
      </#if>
    </#list>
  </#if>
  <#if !attrVar?? && usecase.returnedObject??>
    <#list usecase.returnedObject.attributes as attr>
      <#if attr.name == varname>
        <#local attrVar = attr>
        <#break>
      </#if>
    </#list>
  </#if>
  <#if attrVar??>
    <#return modelbase4java.type_attribute(attrVar)>
  </#if>
  <#return "String">
</#function>

<#macro print_body usecase indent>
  <#if usecase.name?starts_with("find")>
<@print_body_find usecase=usecase indent=indent />
  <#elseif usecase.name?starts_with("save")>
  </#if>
</#macro>

<#macro print_body_find usecase indent>
  <#local paramObj = usecase.parameterizedObject>
  <#if usecase.returnedObject??>
    <#local masterObjs = {}>
    <#local retObj = usecase.returnedObject>
    <#list retObj.attributes as attr>
      <#if attr.isLabelled("original")>
        <#local objname = attr.getLabelledOption("original", "object")>
        <#local opname = attr.getLabelledOption("original", "operator")!"">
        <#if !masterObjs[objname]?? && opname == "">
          <#local masterObjs += {objname: objname}>
${""?left_pad(indent)}${java.nameType(objname)}Query ${java.nameVariable(objname)}Query = new ${java.nameType(objname)}Query();
${""?left_pad(indent)}List<${java.nameType(objname)}> ${java.nameVariable(inflector.pluralize(objname))} = ${java.nameVariable(objname)}Service.find${java.nameType(inflector.pluralize(objname))}(${java.nameVariable(objname)}Query);
        </#if>
      </#if>
    </#list>
    <#local slaveObjs = {}>
    <#list retObj.attributes as attr>
      <#if attr.isLabelled("original")>
        <#local objname = attr.getLabelledOption("original", "object")>
        <#local opname = attr.getLabelledOption("original", "operator")!"">
        <#if !slaveObjs[objname]??>
          <#local slaveObjs += {objname: objname}>
          <#local slaveObj = model.findObjectByName(objname)>
          <#if opname == "count">
${""?left_pad(indent)}${java.nameType(objname)}Query ${java.nameVariable(objname)}Query = new ${java.nameType(objname)}Query();    
            <#list masterObjs?values as masterObjName>
              <#list slaveObj.attributes as attr>
                <#if attr.type.name == masterObjName>
${""?left_pad(indent)}for (${java.nameType(masterObjName)} row : ${java.nameVariable(inflector.pluralize(masterObjName))}) {
${""?left_pad(indent)}  ${java.nameVariable(objname)}Query.add${java.nameType(masterObjName)}(row);
${""?left_pad(indent)}}
                </#if>
              </#list>
            </#list>
${""?left_pad(indent)}List<${modelbase4java.type_attribute_primitive(attr)}> ${java.nameVariable(inflector.pluralize(attr.name))} = ${java.nameVariable(objname)}Service.aggregate${java.nameType(objname)}(${java.nameVariable(objname)}Query);     
          </#if>     
        </#if>
      </#if>
    </#list>
  </#if>
</#macro>

<#macro print_body_get usecase indent>
  <#local paramObj = usecase.parameterizedObject>
  <#if usecase.returnedObject??>
    <#local printedObjs = {}>
    <#local retObj = usecase.returnedObject>
    <#list retObj.attributes as attr>
      <#if attr.isLabelled("original")>
        <#local objname = attr.getLabelledOption("original", "object")>
        <#local opname = attr.getLabelledOption("original", "operator")!"">
        <#if !printedObjs[objname]??>
          <#local printedObjs += {objname: objname}>
          <#if opname == "count">
${""?left_pad(indent)}${java.nameType(objname)}Query ${java.nameVariable(objname)}Query = new ${java.nameType(objname)}Query();          
${""?left_pad(indent)}${modelbase4java.type_attribute_primitive(attr)} ${java.nameVariable(attr.name)} = ${java.nameVariable(objname)}Service.aggregate${java.nameType(objname)}(${java.nameVariable(objname)}Query);          
          <#else>
${""?left_pad(indent)}${java.nameType(objname)}Query ${java.nameVariable(objname)}Query = new ${java.nameType(objname)}Query();
${""?left_pad(indent)}${java.nameType(objname)} ${java.nameVariable(objname)} = ${java.nameVariable(objname)}Service.get${java.nameType(objname)}(${java.nameVariable(objname)}Query);
          </#if>
        </#if>
      </#if>
    </#list>
  </#if>
</#macro>

<#macro print_statement usecase stmt indent>
  <#if stmt.operator?ends_with("?|")>
<@print_statement_comparison usecase=usecase stmt=stmt indent=indent />  
  <#elseif stmt.operator?ends_with("+|")>
<@print_statement_save usecase=usecase stmt=stmt indent=indent />
  <#elseif stmt.operator?ends_with("=|")>
<@print_statement_update usecase=usecase stmt=stmt indent=indent />
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

<#---------->
<#-- 更新 -->
<#---------->
<#macro print_statement_update usecase stmt indent>
  <#local update = stmt>
  <#if update.saveObject??>
    <#local updateObjName = update.saveObject.name?replace("#", "")>
${""?left_pad(indent)}${java.nameVariable(updateObjName)}Service.update${java.nameType(updateObjName)}(${java.nameVariable(updateObjName)});
  </#if>  
</#macro>

<#macro print_statement_assignment usecase stmt indent>
  <#local assign = stmt>
  <#if assign.assignOp == "=">
    <#if assign.value.invocation??>
      <#local invo = assign.value.invocation>
${""?left_pad(indent)}${type_variable(usecase, assign.assignee)} ${java.nameVariable(assign.assignee)} = ${java.nameVariable(invo.method)}(<#list invo.arguments as arg><#if arg?index != 0>,</#if>${java.nameVariable(arg)}</#list>);
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
${""?left_pad(indent)}${java.nameType(uniqueObjName)} ${java.nameVariable(assign.assignee)} = ${java.nameVariable(uniqueObjName)}Service.get${java.nameType(uniqueObjName)}(unique${java.nameType(uniqueObjName)}Query); 
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