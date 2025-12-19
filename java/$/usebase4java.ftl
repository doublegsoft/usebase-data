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
<@print_body_save usecase=usecase indent=indent />  
  </#if>
</#macro>

<#-- 
 * =========================================================================================
 * Macro: print_body_find
 * 
 * 描述 (Description):
 * 该宏用于生成“查询类”用例（Find UseCase）的核心业务逻辑代码。
 * 它能够智能地分析用例的返回对象结构（Returned Object），自动协调主数据查询和关联数据的聚合查询。
 *
 * 核心逻辑 (Core Logic):
 * 1. 识别主对象 (Master Objects):
 *    扫描返回对象的属性，找出那些映射到原始实体且没有聚合操作符（如 count）的属性。
 *    生成代码调用 Service 的 find 方法查询这些主列表（例如：查询“部门列表”）。
 *
 * 2. 识别从对象/聚合对象 (Slave/Aggregated Objects):
 *    扫描返回属性，找出需要进行聚合计算（如 count, sum）的属性。
 *    （例如：需要统计每个部门下的“员工数量”）。
 *
 * 3. 自动关联 (Auto Correlation):
 *    这是该宏最强大的地方。它会自动检测“从对象”中是否存在指向“主对象”的外键关联。
 *    如果存在，它会生成 Java 循环代码，将已查询到的主对象集合作为过滤条件，
 *    传递给从对象的 Query 对象。这通常用于构建类似 "WHERE foreign_key IN (...)" 
 *    的批量查询，从而避免 N+1 查询性能问题。
 *
 * 参数 (Parameters):
 * @param usecase - 当前生成的用例元数据对象 (UseCase Definition)
 * @param indent  - 生成代码的左侧缩进空格数 (Integer)
 * =========================================================================================
 -->
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
${""?left_pad(indent)}List<Map<String,Object>> ${java.nameVariable(inflector.pluralize(attr.name))} = ${java.nameVariable(objname)}Service.aggregate${java.nameType(inflector.pluralize(objname))}(${java.nameVariable(objname)}Query);     
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
${""?left_pad(indent)}List<${java.nameType(objname)}Query> ${java.nameVariable(inflector.pluralize(attr.name))} = ${java.nameVariable(objname)}Service.aggregate${java.nameType(inflector.pluraliz(eobjname))}(${java.nameVariable(objname)}Query);         
          <#else>
${""?left_pad(indent)}${java.nameType(objname)}Query ${java.nameVariable(objname)}Query = new ${java.nameType(objname)}Query();
${""?left_pad(indent)}${java.nameType(objname)} ${java.nameVariable(objname)} = ${java.nameVariable(objname)}Service.get${java.nameType(objname)}(${java.nameVariable(objname)}Query);
          </#if>
        </#if>
      </#if>
    </#list>
  </#if>
</#macro>

<#-- 
 * =========================================================================================
 * Macro: print_body_save
 * 
 * 描述 (Description):
 * 该宏用于生成“保存类”用例（Save UseCase）的核心业务逻辑代码。
 * 它负责将输入参数转换为业务实体，调用 Service 进行持久化，并将结果映射回返回值。
 *
 * 核心逻辑 (Core Logic):
 * 1. 识别主对象 (Identify Master Object):
 *    扫描输入参数对象 (Parameterized Object) 的属性，通过 "original" 标签
 *    找出当前用例主要操作的业务实体名称 (例如：UserForm -> User)。
 *
 * 2. 数据绑定 (Data Binding):
 *    生成代码将 Input DTO 的属性值 Set 到业务 Query/Entity 对象中。
 *
 * 3. 智能保存 (Smart Save):
 *    检查业务对象的主键 (ID)。
 *    - 如果 ID 为空: 调用 Service.create 方法 (新增)。
 *    - 如果 ID 非空: 调用 Service.update 方法 (修改)。
 *
 * 4. 结果映射 (Result Mapping):
 *    如果用例定义了返回值，将保存后（可能包含新生成的ID）的业务对象数据
 *    映射回 Output DTO。
 *
 * 参数 (Parameters):
 * @param usecase - 当前生成的用例元数据对象
 * @param indent  - 生成代码的左侧缩进空格数
 * =========================================================================================
 -->
<#macro print_body_save usecase indent>
  <#local paramObj = usecase.parameterizedObject>
  <#-- 识别要保存的主业务对象 -->
  <#local masterObjName = "">
  <#local slaveObjNames = {}>
  <#list paramObj.attributes as attr>
    <#-- 寻找映射了领域对象的属性 -->
    <#if attr.isLabelled("original")>
      <#local objname = attr.getLabelledOption("original", "object")>
      <#local isArray = attr.getLabelledOption("original", "array")!"false">
      <#if masterObjName == "">
        <#local masterObjName = objname>
      <#elseif masterObjName != objname && !slaveObjNames[objname]??>
        <#local slaveObjNames += {objname: isArray}>
      </#if>
    </#if>
  </#list>
  <#if masterObjName != "">
    <#local typeName = java.nameType(masterObjName)>
    <#local varName = java.nameVariable(masterObjName)>
    <#local masterObj = model.findObjectByName(masterObjName)>
    <#local masterObjIdAttr = modelbase.get_id_attributes(masterObj)?first>
    <#-- 生成主对象的保存代码 -->
${""?left_pad(indent)}${typeName}Query ${varName}Query = new ${typeName}Query();
    <#list paramObj.attributes as attr>
      <#if attr.isLabelled("original") && attr.getLabelledOption("original", "object") == masterObjName>
        <#local targetAttr = attr.getLabelledOption("original", "attribute")>
${""?left_pad(indent)}${varName}Query.set${java.nameType(targetAttr)}(params.get${java.nameType(attr.name)}());
      </#if>
    </#list>
${""?left_pad(indent)}${varName}Query = ${varName}Service.save${typeName}(${varName}Query);
  </#if>
  <#list slaveObjNames?keys as objname>
    <#local slaveObj = model.findObjectByName(objname)>
    <#local slaveObjIdAttr = modelbase.get_id_attributes(slaveObj)?first>
    <#if slaveObjNames[objname] == "true">
      <#list paramObj.attributes as attr>
        <#if attr.type.collection && attr.type.componentType.name == objname>
          <#local conjObjName = attr.getLabelledOption("conjunction", "name")!"">
${""?left_pad(indent)}List<${java.nameType(objname)}Query> ${java.nameVariable(attr.name)} = params.get${java.nameType(attr.name)}();
${""?left_pad(indent)}${java.nameVariable(attr.name)} = ${java.nameVariable(objname)}Service.save${java.nameType(inflector.pluralize(objname))}(${java.nameVariable(attr.name)});    
          <#if conjObjName != "">
            <#local conjObj = model.findObjectByName(conjObjName)>
            <#-- ----------------------------- -->
            <#-- ----------------------------- -->
            <#-- ----------------------------- -->
            <#list conjObj.attributes as conjAttr>
              <#if conjAttr.type.name == masterObj.name>
                <#local anotherRefObj = masterObj>
                <#break>
              </#if>
              <#list slaveObjNames?keys as slaveName>
                <#if conjAttr.type.name == slaveName && slaveObj.name != slaveName>
                  <#local slaveObjIdAttr = conjAttr>
                  <#local anotherRefObj = model.findObjectByName(slaveName)>
                  <#break>
                </#if>
              </#list>  
            </#list>
${""?left_pad(indent)}List<${java.nameType(conjObjName)}Query> ${java.nameVariable(attr.name)}For${java.nameType(conjObjName)} = new ArrayList<>();
${""?left_pad(indent)}for (${java.nameType(objname)}Query item : ${java.nameVariable(attr.name)}) {
${""?left_pad(indent)}  ${java.nameType(conjObjName)}Query conjItem = new ${java.nameType(conjObjName)}Query();
${""?left_pad(indent)}  conjItem.setDefaults();
            <#if anotherRefObj??>
              <#local anotherRefObjIdAttr = modelbase.get_id_attributes(anotherRefObj)?first>
${""?left_pad(indent)}  conjItem.set${java.nameType(modelbase.get_attribute_sql_name(anotherRefObjIdAttr))}(${modelbase.get_attribute_sql_name(anotherRefObjIdAttr)});
            </#if>
            <#-- 寻找从对象中指向主对象的外键属性 -->
            <#list conjObj.attributes as conjAttr>
              <#if conjAttr.type.name == slaveObj.name>
${""?left_pad(indent)}  conjItem.set${java.nameType(modelbase.get_attribute_sql_name(conjAttr))}(item.get${java.nameType(modelbase.get_attribute_sql_name(slaveObjIdAttr))}());
                <#break>
              </#if>
            </#list>  
${""?left_pad(indent)}  ${java.nameVariable(attr.name)}For${java.nameType(conjObjName)}.add(conjItem);
${""?left_pad(indent)}}
${""?left_pad(indent)}${java.nameVariable(attr.name)}For${java.nameType(conjObjName)} = ${java.nameVariable(conjObjName)}Service.save${java.nameType(inflector.pluralize(conjObjName))}(${java.nameVariable(attr.name)}For${java.nameType(conjObjName)});    
          </#if>      
          <#break>
        </#if>
      </#list>
    <#else>
${""?left_pad(indent)}${java.nameType(objname)}Query ${java.nameVariable(objname)}Query = new ${java.nameType(objname)}Query();
${""?left_pad(indent)}${java.nameVariable(objname)}Query = ${java.nameVariable(objname)}Service.save${java.nameType(objname)}(${java.nameVariable(objname)}Query);
    </#if>
  </#list>
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