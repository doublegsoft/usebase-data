<#--
 ### 解析变量名对应的 Java 类型名称。
 ### <p>
 ### 该函数用于在代码生成过程中，推断一个 DSL 变量名（varname）在目标语言（Java）中的具体类型。
 ### 它按照特定的优先级顺序在不同的作用域中查找变量定义。
 ###
 ### 查找优先级 (Resolution Order):
 ### 1. 全局对象 (Global Object): 检查该变量名是否直接对应一个领域对象名 (如 "User")。
 ### 2. 输入参数 (Input DTO): 检查该变量是否为 UseCase 输入对象的属性。
 ### 3. 输出参数 (Output DTO): 检查该变量是否为 UseCase 返回对象的属性。
 ### 4. 默认兜底 (Fallback): 如果都找不到，默认视为 "String" 类型。
 ###
 ### @param usecase
 ###        当前的用例定义上下文
 ### @param varname
 ###        需要解析的变量名称字符串
 ###
 ### @return
 ###        目标语言的类型名称字符串 (例如 "String", "Integer", "UserQuery")
 -->
<#function type_variable usecase varname>
  <#if model.findObjectByName(varname)??>
    <#return java.nameType(varname) + "Query">
  </#if>
  <#if usecase.parameterizedObject??>
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

<#--
 ### 检查指定变量名是否为当前用例输入参数（Input DTO）的属性。
 ### <p>
 ### 该函数用于变量作用域解析。在生成代码时，我们需要知道一个变量名到底是指向
 ### 输入参数中的字段（如 `request.getUsername()`），还是一个局部变量。
 ###
 ### 逻辑流程 (Logic Flow):
 ### 1. 检查用例是否有定义输入对象 (parameterizedObject)。
 ### 2. 遍历输入对象的所有属性。
 ### 3. 比较属性名与传入的变量名。
 ###
 ### @param usecase
 ###        当前用例定义上下文
 ### @param varname
 ###        待检查的变量名称 (String)
 ###
 ### @return
 ###        true 表示该变量是输入参数的属性，false 表示不是
 -->
<#function is_paramobj_attribute usecase varname>
  <#if usecase.parameterizedObject??>
    <#list usecase.parameterizedObject.attributes as attr>
      <#if attr.name == varname>
        <#return true>
      </#if>
    </#list>
  </#if>
  <#return false>
</#function>

<#--
 ### 从输入参数对象中查找对应于指定“关联对象/中间表”的属性定义。
 ### <p>
 ### 该函数用于在 UseCase 的输入 DTO (Parameterized Object) 中，寻找被标记为特定
 ### "conjunction" (多对多关联) 的属性。
 ###
 ### 典型场景：
 ### 假设输入 DTO 为 `UserUpdateDTO`，其中有一个属性 `roleList`。
 ### `roleList` 上标记了 `@conjunction(object="UserRole")`。
 ### 调用此函数传入 "UserRole"，将返回 `roleList` 这个属性定义对象。
 ###
 ### 逻辑流程 (Logic Flow):
 ### 1. 检查是否存在输入参数对象。
 ### 2. 遍历输入对象的所有属性。
 ### 3. 提取属性上的 conjunction 配置名（优先取 "object"，不存在则取 "name"）。
 ### 4. 比对名称，匹配成功则返回该属性定义。
 ###
 ### @param usecase
 ###        当前用例定义上下文
 ### @param conjObjName
 ###        关联对象（中间表）的名称 (String)
 ###
 ### @return
 ###        找到的属性定义对象 (AttributeDefinition)，未找到则无返回值(null)
 -->
<#function get_conjuncted_attribute_from_paramobj usecase conjObjName>
  <#if usecase.parameterizedObject??>
    <#list usecase.parameterizedObject.attributes as attr>
      <#local conjObjNameForAttr = attr.getLabelledOption("conjunction", "object")!"">
      <#if conjObjNameForAttr == "">
        <#local conjObjNameForAttr = attr.getLabelledOption("conjunction", "name")!"">
      </#if>
      <#if conjObjNameForAttr == conjObjName>
        <#return attr>
      </#if>  
    </#list>  
  </#if>
</#function>

<#function name_attribute attr>
  <#local origObjName = attr.getLabelledOption("original", "object")!"">
  <#if origObjName == "">
    <#return attr.name>
  </#if>
  <#local origAttrName = attr.getLabelledOption("original", "attribute")>
  <#if origAttrName == "id" || origAttrName == "name" || origAttrName == "code" || origAttrName == "type">
    <#return origObjName + "_" + origAttrName>
  </#if>
  <#if attr.type.custom && attr.name == attr.type.name>
    <#return attr.name + "_id">
  </#if>
  <#return origAttrName>
</#function>  

<#macro print_body usecase indent>
  <#if usecase.name?starts_with("find")>
<@print_body_find usecase=usecase indent=indent />
  <#elseif usecase.name?starts_with("get")>
<@print_body_get usecase=usecase indent=indent />
  <#elseif usecase.name?starts_with("save")>
<@print_body_save usecase=usecase indent=indent />  
  </#if>
</#macro>

<#-- 
 ### =========================================================================================
 ### Macro: print_body_find
 ### 
 ### 描述 (Description):
 ### 该宏用于生成“查询类”用例（Find UseCase）的核心业务逻辑代码。
 ### 它能够智能地分析用例的返回对象结构（Returned Object），自动协调主数据查询和关联数据的聚合查询。
 ###
 ### 核心逻辑 (Core Logic):
 ### 1. 识别主对象 (Master Objects):
 ###    扫描返回对象的属性，找出那些映射到原始实体且没有聚合操作符（如 count）的属性。
 ###    生成代码调用 Service 的 find 方法查询这些主列表（例如：查询“部门列表”）。
 ###
 ### 2. 识别从对象/聚合对象 (Slave/Aggregated Objects):
 ###    扫描返回属性，找出需要进行聚合计算（如 count, sum）的属性。
 ###    （例如：需要统计每个部门下的“员工数量”）。
 ###
 ### 3. 自动关联 (Auto Correlation):
 ###    这是该宏最强大的地方。它会自动检测“从对象”中是否存在指向“主对象”的外键关联。
 ###    如果存在，它会生成 Java 循环代码，将已查询到的主对象集合作为过滤条件，
 ###    传递给从对象的 Query 对象。这通常用于构建类似 "WHERE foreign_key IN (...)" 
 ###    的批量查询，从而避免 N+1 查询性能问题。
 ###
 ### 参数 (Parameters):
 ### @param usecase - 当前生成的用例元数据对象 (UseCase Definition)
 ### @param indent  - 生成代码的左侧缩进空格数 (Integer)
 ### =========================================================================================
 -->
<#macro print_body_find usecase indent>
  <#local paramObj = usecase.parameterizedObject>
  <#if !usecase.returnedObject??><#return></#if>
  <#local masterObjs = {}>
  <#local retObj = usecase.returnedObject>
  <#-------------------------->
  <#-- 通过关联链条生成查询语句 -->
  <#-------------------------->
  <#local associationChain = associationBuilder.build(paramObj, retObj)>
  <#local objSize = associationChain.getAssociatingObjects()?size>
  <#if associationChain.getAssociatingObjects()?size != 0>
    <#local firstObjInChain = associationChain.getAssociatingObjects()[0]>
  </#if>
  <#if associationChain.getAssociatingObjects()?size != 0>
    <#local lastObjInChain = associationChain.getAssociatingObjects()[objSize - 1]>
  </#if>
  <#local prevObjInChain = firstObjInChain>
  <#list 1..(objSize-1) as index>
    <#local obj = associationChain.getAssociatingObjects()[index]>
    <#if masterObjs[obj.name]??><#continue></#if>
${""?left_pad(indent)}Integer ${java.nameVariable(obj.name)}RowIndex = 0;
${""?left_pad(indent)}Map<Object,Integer> ${java.nameVariable(obj.name)}IdIndexes = new HashMap<>();
    <#local masterObjs += {obj.name:obj.name}>
  </#list>
  <#local masterObjs = {}> 
  <#list 1..(objSize-1) as index>
    <#local obj = associationChain.getAssociatingObjects()[index]>
    <#local masterObjs += {obj.name:obj.name}>
${""?left_pad(indent)}// 查询【${modelbase.get_object_label(obj)}】集合对象       
${""?left_pad(indent)}${java.nameVariable(obj.name)}Query = new ${java.nameType(obj.name)}Query();
${""?left_pad(indent)}${java.nameVariable(obj.name)}Query.setLimit(-1);
    <#if index == 1>
      <#local idAttrFirstObjInChain = modelbase.get_id_attributes(firstObjInChain)?first>
${""?left_pad(indent)}${java.nameVariable(obj.name)}Query.${modelbase4java.name_setter(idAttrFirstObjInChain)}(${modelbase.get_attribute_sql_name(idAttrFirstObjInChain)});    
    <#else>
      <#local idAttrPrevObjInChain = modelbase.get_id_attributes(prevObjInChain)?first>
${""?left_pad(indent)}for (${java.nameType(prevObjInChain.name)}Query row : ${java.nameVariable(inflector.pluralize(prevObjInChain.name))}) {
${""?left_pad(indent)}  ${java.nameVariable(obj.name)}Query.add${java.nameType(modelbase.get_attribute_sql_name(idAttrPrevObjInChain))}(row.get${java.nameType(modelbase.get_attribute_sql_name(idAttrPrevObjInChain))}());
${""?left_pad(indent)}}
    </#if>
${""?left_pad(indent)}Pagination<${java.nameType(obj.name)}Query> paged${java.nameType(inflector.pluralize(obj.name))} = ${java.nameVariable(obj.name)}Service.find${java.nameType(inflector.pluralize(obj.name))}(${java.nameVariable(obj.name)}Query);
${""?left_pad(indent)}List<${java.nameType(obj.name)}Query> ${java.nameVariable(inflector.pluralize(obj.name))} = paged${java.nameType(inflector.pluralize(obj.name))}.getData();        
    <#local prevObjInChain = obj>
  </#list>
  <#-------------------------->
  <#-- 结果对象的自关联查询语句 -->
  <#-------------------------->
  <#list retObj.attributes as attr>
    <#if !attr.isLabelled("original")><#continue></#if>
    <#local objname = attr.getLabelledOption("original", "object")>
    <#local opname = attr.getLabelledOption("original", "operator")!"">
    <#if masterObjs[objname]??><#continue></#if>
      <#-- 当有聚合运算符时，跳过主要对象的查询参数赋值 -->
    <#if opname == "">
      <#-- 当没有运算符的定义时，主要对象的查询参数赋值 -->
      <#local masterObjs += {objname: objname}>
${""?left_pad(indent)}// 查询【${modelbase.get_object_label(model.findObjectByName(objname))}】集合对象       
${""?left_pad(indent)}${java.nameVariable(objname)}Query = new ${java.nameType(objname)}Query();
${""?left_pad(indent)}${java.nameVariable(objname)}Query.setLimit(-1);
      <#list paramObj.attributes as paramAttr>
        <#local originalObjName = paramAttr.getLabelledOption("original", "object")!"">
        <#if originalObjName == objname>
${""?left_pad(indent)}${java.nameVariable(objname)}Query.set${java.nameType(modelbase.get_attribute_sql_name(paramAttr))}(${modelbase.get_attribute_sql_name(paramAttr)});
        </#if>
      </#list>
    </#if>
    <#if attr.getLabelledOption("conjunction", "target_attribute")??>
      <#local masterObjs += {objname: objname}>
      <#local targetObjName = attr.getLabelledOption("conjunction", "target_object")>
      <#local targetAttrName = attr.getLabelledOption("conjunction", "target_attribute")>
      <#local sourceObjName = attr.getLabelledOption("conjunction", "source_object")>
      <#local sourceAttrName = attr.getLabelledOption("conjunction", "source_attribute")>
      <#local targetObj = model.findObjectByName(targetObjName)>
      <#local targetObjAttr = targetObj.getAttribute(targetAttrName)>
      <#local sourceObj = model.findObjectByName(sourceObjName)>
      <#local sourceObjAttr = sourceObj.getAttribute(sourceAttrName)> 
${""?left_pad(indent)}for (${java.nameType(targetObj.name)}Query row : ${java.nameVariable(inflector.pluralize(targetObj.name))}) {
${""?left_pad(indent)}  ${java.nameVariable(sourceObj.name)}Query.add${java.nameType(modelbase.get_attribute_sql_name(sourceObjAttr))}(row.get${java.nameType(modelbase.get_attribute_sql_name(targetObjAttr))}());
${""?left_pad(indent)}}
    </#if>     
${""?left_pad(indent)}Pagination<${java.nameType(objname)}Query> paged${java.nameType(inflector.pluralize(objname))} = ${java.nameVariable(objname)}Service.find${java.nameType(inflector.pluralize(objname))}(${java.nameVariable(objname)}Query);
${""?left_pad(indent)}List<${java.nameType(objname)}Query> ${java.nameVariable(inflector.pluralize(objname))} = paged${java.nameType(inflector.pluralize(objname))}.getData();    
  </#list>
  <#local slaveObjs = {}>
  <#list retObj.attributes as attr>
    <#if attr.isLabelled("original")>
      <#local objname = attr.getLabelledOption("original", "object")>
      <#local opname = attr.getLabelledOption("original", "operator")!"">
      <#if slaveObjs[objname]??><#continue></#if>
      <#local slaveObjs += {objname: objname}>
      <#local slaveObj = model.findObjectByName(objname)>
      <#if opname == "count">
${""?left_pad(indent)}${java.nameVariable(objname)}Query = new ${java.nameType(objname)}Query();    
        <#list masterObjs?values as masterObjName>
          <#local masterObj = model.findObjectByName(masterObjName)>
          <#local masterObjIdAttr = modelbase.get_id_attributes(masterObj)?first>
          <#list slaveObj.attributes as attr>
            <#if attr.type.name == masterObjName>
${""?left_pad(indent)}${java.nameVariable(masterObjName)}RowIndex = 0;              
${""?left_pad(indent)}for (${java.nameType(masterObjName)}Query row : ${java.nameVariable(inflector.pluralize(masterObjName))}) {
${""?left_pad(indent)}  ${java.nameVariable(objname)}Query.add${java.nameType(modelbase.get_attribute_sql_name(masterObjIdAttr))}(row.get${java.nameType(modelbase.get_attribute_sql_name(masterObjIdAttr))}());
${""?left_pad(indent)}  ${java.nameVariable(masterObjName)}IdIndexes.put(row.get${java.nameType(modelbase.get_attribute_sql_name(masterObjIdAttr))}(), ${java.nameVariable(masterObjName)}RowIndex++);     
${""?left_pad(indent)}}
            </#if>
          </#list>
        </#list>
${""?left_pad(indent)}List<Map<String,Object>> ${java.nameVariable(inflector.pluralize(attr.name))} = ${java.nameVariable(objname)}Service.aggregate${java.nameType(objname)}(${java.nameVariable(objname)}Query);     
      </#if> 
    </#if>
  </#list>
</#macro>

<#-- 
 ### =========================================================================================
 ### Macro: print_body_get
 ### 
 ### 描述 (Description):
 ### 该宏用于生成“获取单条信息类”用例（Get UseCase）的核心业务逻辑代码。
 ### 它分析返回对象（Output DTO），根据属性映射自动调用相应的 Service 方法来获取数据或统计信息。
 ###
 ### 核心逻辑 (Core Logic):
 ### 1. 遍历返回属性 (Iterate Attributes):
 ###    扫描返回对象的所有属性，查找标记为 "original" 的属性，确定对应的领域对象。
 ###
 ### 2. 去重处理 (De-duplication):
 ###    使用 'printedObjs' 集合防止对同一个领域对象重复生成查询代码。
 ###    例如：如果返回值有 name 和 email 都来自 User 对象，只生成一次 User 查询。
 ###
 ### 3. 区分操作类型 (Operation Type Dispatch):
 ###    - 聚合查询 (count): 调用 aggregate{Obj} 方法。
 ###    - 单条查询 (default): 调用 get{Obj} 方法。
 ###
 ### 注意 (Note):
 ### 当前代码仅生成了 new Query()，通常还需要从 paramObj 中获取 ID 并设置到 Query 中
 ### (例如: userQuery.setId(input.getId()))，这部分逻辑可能需要根据实际 ID 命名规则补充。
 ###
 ### 参数 (Parameters):
 ### @param usecase - 当前生成的用例元数据对象
 ### @param indent  - 生成代码的左侧缩进空格数
 ### =========================================================================================
 -->
<#macro print_body_get usecase indent>
  <#local paramObj = usecase.parameterizedObject>
  <#local retObj = usecase.returnedObject>
  <#local singleObjs = usebase.group_single_objects(paramObj)>
  <#local arrayObjs = usebase.group_array_objects(paramObj)>
  <#------------------->
  <#-- 1. 查询参数校验 -->
  <#------------------->
  <#local groups = usebase.group_unique_attributes(paramObj)>
  <#local allGroupingAttrs = []>
  <#list groups?values as attrs>
    <#local allGroupingAttrs += attrs>
  </#list>
  <#if allGroupingAttrs?size != 0>
    <#local attr = allGroupingAttrs[0]>
${""?left_pad(indent)}if (Objects.isEmpty(${java.nameVariable(attr.name)})<#if allGroupingAttrs?size != 1> &&<#else>) {</#if>
  </#if>
  <#list allGroupingAttrs as attr>
    <#if attr?index == 0><#continue></#if>
${""?left_pad(indent)}    Objects.isEmpty(${java.nameVariable(attr.name)})<#if attr?index != allGroupingAttrs?size - 1> &&<#else>) {</#if>
  </#list>
  <#if allGroupingAttrs?size != 0>
${""?left_pad(indent)}  throw new ServiceException(400, "数据唯一性校验所需参数全部为空！");
${""?left_pad(indent)}}
  </#if>
  <#----------------------------------------------------------->
  <#-- 2. 通过参数查询“聚根”对象，包括：查询声明，条件设置，结果判断。 -->
  <#----------------------------------------------------------->
  <#local alreadyDeclaredObjs = {}>
  <#list groups?values as attrs>
    <#list attrs as attr>
      <#local objname = attr.getLabelledOption("original", "object")>
      <#local obj = model.findObjectByName(objname)>
      <#local alreadyDeclaredObjs += {objname: obj}>
      <#if attr?index == 0>
${""?left_pad(indent)}if (!Objects.isEmpty(${java.nameVariable(attr.name)})<#if attr?index != attrs?size - 1> &&<#else>) {</#if>
      <#else>
${""?left_pad(indent)}    !Objects.isEmpty(${java.nameVariable(attr.name)})<#if attr?index != attrs?size - 1> &&<#else>) {</#if>
      </#if>
    </#list>
${""?left_pad(indent)}  ${java.nameVariable(objname)}Query = new ${java.nameType(objname)}Query();
    <#list attrs as attr>
${""?left_pad(indent)}  ${java.nameVariable(objname)}Query.set${java.nameType(modelbase.get_attribute_sql_name(attr))}(${java.nameVariable(modelbase.get_attribute_sql_name(attr))});
    </#list>
${""?left_pad(indent)}  ${java.nameVariable(objname)} = ${java.nameVariable(objname)}Service.get${java.nameType(objname)}(${java.nameVariable(objname)}Query);    
${""?left_pad(indent)}}
  </#list>
${""?left_pad(indent)}if (${java.nameVariable(objname)} == null) {
${""?left_pad(indent)}  throw new ServiceException(404, "${modelbase.get_object_label(obj)}不存在");
${""?left_pad(indent)}}
  <#------------------------------------------------------------------>
  <#-- 3. 根据查询出其余的对象组合成返回的“聚根”对象，包括：单一对象和数组对象 -->
  <#------------------------------------------------------------------>
  <#-------------------------------------->
  <#-- 声明全部需要查询集合属性的查询条件对象 -->
  <#-------------------------------------->
  <#local relatingObjs = usebase.group_relating_objects(retObj)>
  <#local singleObjs = usebase.group_single_objects(retObj)>
  <#local arrayObjs = usebase.group_array_objects(retObj)>
  <#list relatingObjs as obj>
${""?left_pad(indent)}${java.nameVariable(obj.name)}Query = new ${java.nameType(obj.name)}Query();  
${""?left_pad(indent)}${java.nameVariable(obj.name)}Query.setLimit(-1);
  </#list>
  <#-------------------------------------->
  <#-- 声明全部查询结果对象 -->
  <#-------------------------------------->
  <#list relatingObjs as singleObj>
    <#if !singleObjs[singleObj.name]?? || alreadyDeclaredObjs[singleObj.name]??><#continue></#if>
${""?left_pad(indent)}${java.nameType(singleObj.name)}Query ${java.nameVariable(singleObj.name)} = null;
  </#list>
  <#list relatingObjs as arrayObj>
    <#if !arrayObjs[arrayObj.name]??><#continue></#if>
${""?left_pad(indent)}List<${java.nameType(arrayObj.name)}Query> ${java.nameVariable(inflector.pluralize(arrayObj.name))} = new ArrayList<>();
  </#list>
  <#local aggregateChain = aggregateBuilder.build(retObj)>
  <#local objRelsList = aggregateChain.build()>
  <#local visitedObjs = {}>
  <#list objRelsList as objRels>
    <#local obj = objRels.object>
    <#local objIdAttr = modelbase.get_id_attributes(obj)?first>
    <#if singleObjs[obj.name]??>
      <#if objRels?index != 0>
${""?left_pad(indent)}// 查询【${modelbase.get_object_label(obj)}】数据          
${""?left_pad(indent)}${java.nameVariable(obj.name)} = ${java.nameVariable(obj.name)}Service.get${java.nameType(obj.name)}(${java.nameVariable(obj.name)}Query);
      </#if>
      <#list objRels.relationships as rel>
        <#local selfObj = rel.getAnotherObject(obj.name)>
        <#local selfAttr = rel.getAnotherAttribute(obj.name)>
        <#local anotherObj = rel.getAnotherObject(obj.name)>
        <#local anotherAttr = rel.getAnotherAttribute(obj.name)>
        <#if visitedObjs[anotherObj.name]??><#continue></#if>
${""?left_pad(indent)}if (${java.nameVariable(obj.name)} != null && ${java.nameVariable(obj.name)}.get${java.nameType(modelbase.get_attribute_sql_name(selfAttr))}() != null) {
${""?left_pad(indent)}  ${java.nameVariable(anotherObj.name)}Query.set${java.nameType(modelbase.get_attribute_sql_name(anotherAttr))}(${java.nameVariable(obj.name)}.get${java.nameType(modelbase.get_attribute_sql_name(selfAttr))}());  
${""?left_pad(indent)}}   
      </#list>
    <#elseif arrayObjs[obj.name]??> 
      <#local strongObjRels = aggregateChain.getStrongObjectRelationships(obj.name)>
${""?left_pad(indent)}// 查询【${modelbase.get_object_label(obj)}】集合对象
      <#if strongObjRels.array == true>
${""?left_pad(indent)}if (!${java.nameVariable(inflector.pluralize(strongObjRels.object.name))}.isEmpty()) {      
      <#else>
${""?left_pad(indent)}if (true) {
      </#if>
${""?left_pad(indent)}  List<${java.nameType(obj.name)}Query> data = ${java.nameVariable(obj.name)}Service.find${java.nameType(inflector.pluralize(obj.name))}(${java.nameVariable(obj.name)}Query).getData();
${""?left_pad(indent)}  ${java.nameVariable(inflector.pluralize(obj.name))}.addAll(data);
${""?left_pad(indent)}}
      <#-- 避免打印多余的for循环语句 -->
      <#local haveStatementsInLoop = false>
      <#list objRels.relationships as rel>
        <#local anotherObj = rel.getAnotherObject(obj.name)>
        <#local anotherAttr = rel.getAnotherAttribute(obj.name)>
        <#if visitedObjs[anotherObj.name]??><#continue></#if>
        <#local haveStatementsInLoop = true>
      </#list>
      <#if !haveStatementsInLoop><#continue></#if>
${""?left_pad(indent)}for (${java.nameType(obj.name)}Query row : ${java.nameVariable(inflector.pluralize(obj.name))}) {
      <#list objRels.relationships as rel>
        <#local selfObj = rel.getAnotherObject(obj.name)>
        <#local selfAttr = rel.getAnotherAttribute(obj.name)>
        <#local anotherObj = rel.getAnotherObject(obj.name)>
        <#local anotherAttr = rel.getAnotherAttribute(obj.name)>
        <#if visitedObjs[anotherObj.name]??><#continue></#if>
${""?left_pad(indent)}  ${java.nameVariable(anotherObj.name)}Query.add${java.nameType(modelbase.get_attribute_sql_name(anotherAttr))}(row.get${java.nameType(modelbase.get_attribute_sql_name(selfAttr))}());  
        <#local visitedObjs += {anotherObj.name: anotherObj}>
      </#list>
${""?left_pad(indent)}}      
    </#if>
    <#local visitedObjs += {obj.name: obj}>
  </#list>
</#macro>

<#-- 
 ### =========================================================================================
 ### Macro: print_body_save
 ### 
 ### 描述 (Description):
 ### 该宏用于生成“保存类”用例（Save UseCase）的核心业务逻辑代码。
 ### 它负责将输入参数转换为业务实体，调用 Service 进行持久化，并将结果映射回返回值。
 ###
 ### 核心逻辑 (Core Logic):
 ### 1. 识别主对象 (Identify Master Object):
 ###    扫描输入参数对象 (Parameterized Object) 的属性，通过 "original" 标签
 ###    找出当前用例主要操作的业务实体名称 (例如：UserForm -> User)。
 ###
 ### 2. 数据绑定 (Data Binding):
 ###    生成代码将 Input DTO 的属性值 Set 到业务 Query/Entity 对象中。
 ###
 ### 3. 智能保存 (Smart Save):
 ###    检查业务对象的主键 (ID)。
 ###    - 如果 ID 为空: 调用 Service.create 方法 (新增)。
 ###    - 如果 ID 非空: 调用 Service.update 方法 (修改)。
 ###
 ### 4. 结果映射 (Result Mapping):
 ###    如果用例定义了返回值，将保存后（可能包含新生成的ID）的业务对象数据
 ###    映射回 Output DTO。
 ###
 ### 参数 (Parameters):
 ### @param usecase - 当前生成的用例元数据对象
 ### @param indent  - 生成代码的左侧缩进空格数
 ### =========================================================================================
 -->
<#macro print_body_save usecase indent>
  <#local paramObj = usecase.parameterizedObject>
  <#-- 识别要保存的主业务对象 -->
  <#local masterObjName = "">
  <#local slaveObjNames = {}>
  <#list paramObj.attributes as attr>
    <#-- 寻找映射了领域对象的属性 -->
    <#if attr.isLabelled("original")>
      <#local objname = attr.getLabelledOption("original", "object")!"">
      <#local isArray = attr.getLabelledOption("original", "array")!"false">
      <#if attr.type.collection>
        <#local isArray = "true">
      </#if>
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
${""?left_pad(indent)}${varName}Query = new ${typeName}Query();
    <#list paramObj.attributes as attr>
      <#if attr.isLabelled("original") && (attr.getLabelledOption("original", "object")!"") == masterObjName>
        <#local targetAttrName = attr.getLabelledOption("original", "attribute")>
        <#local targetAttr = model.findAttributeByNames(masterObjName, targetAttrName)>
${""?left_pad(indent)}${varName}Query.${modelbase4java.name_setter(targetAttr)}(params.get${java.nameType(name_attribute(attr))}());
      </#if>
    </#list>
${""?left_pad(indent)}${varName} = ${varName}Service.save${typeName}(${varName}Query);
  </#if>
  <#list slaveObjNames?keys as objname>
    <#local slaveObj = model.findObjectByName(objname)>
    <#local slaveObjIdAttr = modelbase.get_id_attributes(slaveObj)?first>
    <#if slaveObjNames[objname] == "true">
      <#list paramObj.attributes as attr>
        <#if attr.type.collection && attr.type.componentType.name == objname>
          <#local conjObjName = attr.getLabelledOption("conjunction", "name")!"">
${""?left_pad(indent)}List<${java.nameType(objname)}Query> ${java.nameVariable(objname)}Queries = new ArrayList<>();
${""?left_pad(indent)}for (${java.nameType(objname)}Info item : ${java.nameVariable(attr.name)}) {
${""?left_pad(indent)}  ${java.nameType(objname)}Query itemQuery = new ${java.nameType(objname)}Query();
${""?left_pad(indent)}  ${java.nameType(objname)}Query.setDefaultValues(itemQuery);
          <#list slaveObj.attributes as slaveObjAttr>
            <#if slaveObjAttr.type.custom && slaveObjAttr.type.name != masterObjName>
${""?left_pad(indent)}  itemQuery.set${java.nameType(modelbase.get_attribute_sql_name(slaveObjAttr))}(item.get${java.nameType(modelbase.get_attribute_sql_name(slaveObjAttr))}());
              <#break>
            </#if>
          </#list>
${""?left_pad(indent)}  itemQuery.set${java.nameType(modelbase.get_attribute_sql_name(slaveObjIdAttr))}(${java.nameVariable(masterObjName)}.get${java.nameType(modelbase.get_attribute_sql_name(masterObjIdAttr))}());
${""?left_pad(indent)}  ${java.nameVariable(objname)}Queries.add(itemQuery);
${""?left_pad(indent)}}
${""?left_pad(indent)}${java.nameVariable(objname)}Service.save${java.nameType(inflector.pluralize(objname))}(${java.nameVariable(objname)}Queries);    
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
${""?left_pad(indent)}${java.nameVariable(objname)}Query = new ${java.nameType(objname)}Query();
${""?left_pad(indent)}${java.nameType(objname)}Query ${java.nameVariable(objname)} = ${java.nameVariable(objname)}Service.save${java.nameType(objname)}(${java.nameVariable(objname)}Query);
    </#if>
  </#list>
</#macro>

<#macro print_statement usecase stmt indent>
  <#if stmt.operator?ends_with("+|")>
<@print_statement_save usecase=usecase stmt=stmt indent=indent />
  <#elseif stmt.operator?ends_with("=|")>
<@print_statement_update usecase=usecase stmt=stmt indent=indent />
  <#elseif stmt.operator?ends_with(":|")>
<@print_statement_assignment usecase=usecase stmt=stmt indent=indent />  
  <#elseif stmt.operator?ends_with("?|")>
<@print_statement_comparison usecase=usecase stmt=stmt indent=indent />  
  <#elseif stmt.operator?ends_with("@|")>
<@print_statement_invocation usecase=usecase stmt=stmt indent=indent />
  <#elseif stmt.operator?ends_with("&|")>
<@print_statement_find usecase=usecase stmt=stmt indent=indent />    
  <#elseif stmt.operator?ends_with(".|")>
<@print_statement_return usecase=usecase stmt=stmt indent=indent />
  <#elseif stmt.operator?ends_with("*|")>
<@print_statement_loop usecase=usecase stmt=stmt indent=indent />
  </#if>
</#macro>

<#macro print_statement_save usecase stmt indent>
  <#local save = stmt>
  <#if save.saveObject??>
    <#local saveObjName = save.saveObject.name?replace("#", "")>
    <#local saveObjIdAttr = modelbase.get_id_attributes(model.findObjectByName(saveObjName))[0]>
    <#if save.array == true>
      <#local saveObjName = saveObjName?replace("[]", "")>
      <#---------------------------------------------------->
      <#-- 判断段这个集合对象是参数对象中的连接条件还是连接对象    -->
      <#-- 如果是连接条件对象，从连接对象中封装为连接条件对象在保存 -->
      <#---------------------------------------------------->
      <#if is_paramobj_attribute(usecase, save.variable)>
${""?left_pad(indent)}for (${java.nameType(saveObjName)}Query row : ${java.nameVariable(save.variable)}) {
${""?left_pad(indent)}
${""?left_pad(indent)}}
      <#else>
        <#local conjedAttr = get_conjuncted_attribute_from_paramobj(usecase, saveObjName)>
        <#local targetObjName = conjedAttr.getLabelledOption("conjunction", "target_object")>
        <#local origObjName = conjedAttr.getLabelledOption("original", "object")>
        <#local origObjIdAttr = modelbase.get_id_attributes(model.findObjectByName(origObjName))?first>
        <#local targetObjIdAttr = modelbase.get_id_attributes(model.findObjectByName(targetObjName))?first>
${""?left_pad(indent)}List<${java.nameType(saveObjName)}Query> ${java.nameVariable(save.variable)} = new ArrayList<>();
${""?left_pad(indent)}for (${java.nameType(origObjName)}Info row : ${java.nameVariable(conjedAttr.name)}) {
${""?left_pad(indent)}  ${java.nameVariable(saveObjName)} = new ${java.nameType(saveObjName)}Query();
${""?left_pad(indent)}  ${java.nameType(saveObjName)}Query.setDefaultValues(${java.nameVariable(saveObjName)}, true);
${""?left_pad(indent)}  ${java.nameVariable(saveObjName)}.set${java.nameType(modelbase.get_attribute_sql_name(origObjIdAttr))}(row.get${java.nameType(modelbase.get_attribute_sql_name(origObjIdAttr))}());
${""?left_pad(indent)}  ${java.nameVariable(saveObjName)}.set${java.nameType(modelbase.get_attribute_sql_name(targetObjIdAttr))}(${java.nameVariable(targetObjName)}.get${java.nameType(modelbase.get_attribute_sql_name(targetObjIdAttr))}());
${""?left_pad(indent)}  ${java.nameVariable(save.variable)}.add(${java.nameVariable(saveObjName)});
${""?left_pad(indent)}}
${""?left_pad(indent)}${java.nameVariable(saveObjName)}Service.save${java.nameType(inflector.pluralize(saveObjName))}(${java.nameVariable(save.variable)});  
      </#if>  
    <#else>
${""?left_pad(indent)}${java.nameVariable(save.variable)} = new ${java.nameType(saveObjName)}Query();
      <#list save.saveObject.attributes as attr>
        <#if attr.value??>
${""?left_pad(indent)}${java.nameVariable(save.variable)}.${modelbase4java.name_setter(attr)}(${usebase4java.get_attribute_default_value(usecase, attr)});    
        <#elseif attr.type.custom && !attr.identifiable>
${""?left_pad(indent)}${java.nameVariable(save.variable)}.${modelbase4java.name_setter(attr)}(${modelbase.get_attribute_sql_name(attr)});    
        <#else>
${""?left_pad(indent)}${java.nameVariable(save.variable)}.set${java.nameType(attr.name)}(${java.nameVariable(attr.name)});
        </#if>
      </#list>
${""?left_pad(indent)}${java.nameVariable(saveObjName)}Service.save${java.nameType(saveObjName)}(${java.nameVariable(save.variable)});
      <#if usecase.getVariable(saveObjName + "_" + saveObjIdAttr.name)?? || usecase.getVariable(saveObjIdAttr.name)??>
${""?left_pad(indent)}${modelbase.get_attribute_sql_name(saveObjIdAttr)} = ${java.nameVariable(save.variable)}.${modelbase4java.name_getter(saveObjIdAttr)}();
      </#if>
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
${""?left_pad(indent)}${java.nameVariable(updateObjName)}Query = new ${java.nameType(updateObjName)}Query();
<#-- 设置更新条件 -->    
<@print_unique_labels_setter varname=(updateObjName + "Query") objval=update.saveObject indent=indent />     
${""?left_pad(indent)}${java.nameVariable(updateObjName)} = ${java.nameVariable(updateObjName)}Service.get${java.nameType(updateObjName)}(${java.nameVariable(updateObjName)}Query);
${""?left_pad(indent)}if (${java.nameVariable(updateObjName)} == null) {
${""?left_pad(indent)}  throw new ServiceException(404, "${modelbase.get_object_label(model.findObjectByName(updateObjName))}不存在");
${""?left_pad(indent)}}
    <#list update.saveObject.attributes as attr>
      <#if attr.value??>
${""?left_pad(indent)}${java.nameVariable(update.variable)}.${modelbase4java.name_setter(attr)}(${usebase4java.get_attribute_default_value(usecase, attr)});    
      </#if>
    </#list>
${""?left_pad(indent)}${java.nameVariable(updateObjName)}Service.update${java.nameType(updateObjName)}(${java.nameVariable(updateObjName)});
  </#if>  
</#macro>

<#--
 ### 生成赋值语句的 Java 代码。
 ### <p>
 ### 该宏作为赋值操作的“主路由”，根据赋值符号右侧（RHS）的值类型，
 ### 决定生成哪种类型的赋值代码。
 ###
 ### 支持的赋值场景 (Logic Dispatch):
 ### 1. 方法调用 (Invocation): 调用 Helper 方法并将结果赋值给变量。
 ###    例如: `String hash = helper.encrypt(password);`
 ### 2. 对象赋值 (Object Value): 委托给 `print_assignment_simple_for_object` 宏处理。
 ###    通常用于根据唯一键查找单个对象。
 ### 3. 数组赋值 (Array Value): 委托给 `print_assignment_simple_for_array` 宏处理。
 ###    通常用于列表数据的转换或查找。
 ###
 ### @param usecase
 ###        当前用例定义上下文
 ### @param stmt
 ###        赋值语句对象 (Assignment Statement)
 ### @param indent
 ###        代码缩进级别
 -->
<#macro print_statement_assignment usecase stmt indent>
  <#local assign = stmt>
  <#if assign.assignOp == "=">
    <#if assign.value.invocation??>
      <#local invo = assign.value.invocation>
${""?left_pad(indent)}${type_variable(usecase, assign.assignee)} ${java.nameVariable(assign.assignee)} = helper.${java.nameVariable(invo.method)}(<#list invo.arguments as arg><#if arg?index != 0>,</#if>${java.nameVariable(arg)}</#list>);
    <#elseif assign.value.objectValue??>
<@print_assignment_simple_for_object usecase=usecase assign=assign indent=indent />
    <#elseif assign.value.arrayValue??>
<@print_assignment_simple_for_array usecase=usecase assign=assign indent=indent />      
    <#else>
${""?left_pad(indent)}// ${assign.originalText}      
    </#if>
  <#else>
${""?left_pad(indent)}// 其他赋值操作暂不支持
  </#if>
</#macro>

<#--
 ### 生成基于方法调用结果的比较/校验代码。
 ### <p>
 ### 该宏处理 DSL 中的比较语句（Comparison Statement），特别是当比较的一方是一个函数调用（Invocation），
 ### 且定义了错误消息时。这通常用于业务规则校验。
 ###
 ### 典型场景:
 ### 验证码校验。DSL: `inputCaptcha != helper.generateCaptcha()` error "验证码错误"。
 ### 生成代码: 先调用 helper 获取真值，然后对比，如果不一致则抛出 ServiceException。
 ###
 ### 逻辑流程 (Logic Flow):
 ### 1. 检查语句是否包含方法调用且配置了错误消息 (error message)。
 ### 2. 检查比较符是否为 '!=' (不等于)。
 ### 3. 生成代码调用 Helper 方法获取预期值。
 ### 4. 生成 if (!equals) 代码块进行校验。
 ### 5. 如果校验失败，生成抛出异常的代码。
 ###
 ### @param usecase
 ###        当前用例定义上下文
 ### @param stmt
 ###        比较语句对象 (Statement definition)
 ### @param indent
 ###        代码缩进级别
 -->
<#macro print_statement_comparison usecase stmt indent>
  <#local cmp = stmt>
  <#if cmp.value?? && cmp.value.invocation??>
    <#local invo = cmp.value.invocation>
    <#if invo.error??>
      <#if cmp.comparator == '!='>
${""?left_pad(indent)}String ${usebase.name_method_return(invo.method)} = helper.${java.nameVariable(invo.method)}();      
${""?left_pad(indent)}if (!${cmp.comparand}.equals(${usebase.name_method_return(invo.method)})) {
${""?left_pad(indent)}  throw new ServiceException(400, "${invo.error}");
${""?left_pad(indent)}}      
      </#if>
    </#if>
  <#elseif cmp.value??>
    <#if cmp.andComparisons?size == 0>
${""?left_pad(indent)}if (<@print_single_comparison cmp=cmp indent=0 />) {
    <#else>
${""?left_pad(indent)}if (<@print_single_comparison cmp=cmp indent=0 />
    <#list cmp.andComparisons as andCmp>
<@print_single_comparison cmp=andCmp indent=indent+4 conj="&& " /><#if andCmp?index == cmp.andComparisons?size - 1>) {</#if>
    </#list> 
    </#if>
    <#if cmp.statements?size == 0 && cmp.error??>
${""?left_pad(indent)}  throw new ServiceException(400, "${cmp.error}");    
    </#if>
    <#list stmt.statements as innerStmt>
<@print_statement usecase=usecase stmt=innerStmt indent=indent+2 />
    </#list>
${""?left_pad(indent)}}
  </#if>
</#macro>

<#macro print_single_comparison cmp indent conj="">
  <#compress>
    <#if cmp.value.keyword?? && cmp.value.keyword == "null">
${""?left_pad(indent)}${conj}${java.nameVariable(cmp.comparand)} ${cmp.comparator} null
    <#elseif cmp.value.keyword?? && cmp.value.keyword == "now">
${""?left_pad(indent)}${conj}${java.nameVariable(cmp.comparand)}.equals(new java.sql.Timestamp(System.currentTimeMillis())) 
    <#elseif cmp.value.variable?? >
      <#local comStrs = cmp.comparand?split(".")>
      <#local varStrs = cmp.value.variable?split(".")>
      <#if varStrs?size == 1>
        <#local varExpr = java.nameVariable(varStrs[0])>
      <#else>
        <#local varExpr = java.nameVariable(varStrs[0]) + ".get" + java.nameType(varStrs[1]) + "()">
      </#if>
      <#if comStrs?size == 1>
        <#local comExpr = java.nameVariable(comStrs[0])>
      <#else>
        <#local comExpr = java.nameVariable(comStrs[0]) + ".get" + java.nameType(comStrs[1]) + "()">
      </#if>
${""?left_pad(indent)}${comExpr}.equals(${varExpr})          
    </#if>
  </#compress>
</#macro>

<#--
 ### 生成 Helper 方法调用语句。
 ### <p>
 ### 该宏用于生成对辅助类（Helper）方法的调用代码。通常用于处理不涉及赋值的独立操作。
 ### 
 ### 生成代码示例:
 ### `helper.sendEmail(userId, subject);`
 ###
 ### 逻辑流程:
 ### 1. 获取调用定义 (Invocation)。
 ### 2. 生成 `helper.` 前缀。
 ### 3. 格式化方法名。
 ### 4. 遍历并生成参数列表，自动处理逗号分隔。
 ###
 ### @param usecase
 ###        当前用例定义上下文
 ### @param stmt
 ###        调用语句对象
 ### @param indent
 ###        代码缩进级别
 -->
<#macro print_statement_invocation usecase stmt indent>
  <#local invo = stmt.invocation>
${""?left_pad(indent)}helper.${java.nameVariable(invo.method)}(<#list invo.arguments as arg><#if arg?index != 0>,</#if>${java.nameVariable(arg)}</#list>);      
</#macro>

<#--
 ### 生成返回值装配代码。
 ### <p>
 ### 该宏并不直接生成 `return` 关键字，而是负责将局部变量的数据“拷贝”或“映射”到
 ### 预定义的返回值对象（通常命名为 `retVal`）中。
 ###
 ### 假设前提:
 ### 1. 上下文中已经创建了一个名为 `retVal` 的 Output DTO 对象。
 ### 2. Output DTO 中生成了名为 `copyFrom{Type}` 的辅助方法。
 ###
 ### 逻辑流程:
 ### 1. 遍历需要返回的变量列表。
 ### 2. 解析变量定义 (Variable Definition)。
 ### 3. 根据变量类型（集合 vs 单个对象）调用不同的拷贝方法：
 ###    - 集合类型: 调用 `retVal.copyFrom{PluralName}(var)`
 ###    - 单个类型: 调用 `retVal.copyFrom{SingularName}(var)`
 ###
 ### @param usecase
 ###        当前用例定义上下文
 ### @param stmt
 ###        返回语句对象 (包含要返回的变量名列表)
 ### @param indent
 ###        代码缩进级别
 -->
<#macro print_statement_return usecase stmt indent>
  <#list stmt.variables as varname>
    <#local varObj = usecase.getVariable(varname)>
    <#if varObj.collection>
${""?left_pad(indent)}retVal.copyFrom${java.nameType(inflector.pluralize(varObj.type.name))}(${java.nameVariable(varname)});    
    <#else>
${""?left_pad(indent)}retVal.copyFrom${java.nameType(varObj.type.name)}(${java.nameVariable(varname)});
    </#if>
  </#list>
</#macro>

<#--
 ### 生成数据库查询（Find）语句的 Java 代码。
 ### <p>
 ### 该宏根据赋值语句右值（RHS）的结构，生成调用 Service 层进行数据查询的代码。
 ### 支持两种查询模式：
 ### 1. 集合查询 (Array Value): 查询符合条件的所有记录列表。
 ### 2. 单对象查询 (Object Value): 查询符合条件的第一条记录。
 ###
 ### 核心逻辑 (Core Logic):
 ### 1. 构建查询对象 (Query DTO) 并取消分页限制 (Limit -1)。
 ### 2. 绑定查询条件：遍历 DSL 中定义的 `unique` 属性，将其作为查询参数。
 ###    (注意：假设当前上下文中存在与属性同名的变量作为参数值)。
 ### 3. 调用 Service 的 `find` 方法。
 ### 4. 结果处理：
 ###    - 对于数组：将结果添加到列表。
 ###    - 对于对象：取结果集的第一条数据 (get(0))。
 ### 5. 存在性校验：如果 DSL 定义了 `required` 消息，当查询结果为空时抛出 404 异常。
 ###
 ### @param usecase
 ###        当前用例定义上下文
 ### @param stmt
 ###        查找/赋值语句对象
 ### @param indent
 ###        代码缩进级别
 -->
<#macro print_statement_find usecase stmt indent>
  <#local assign = stmt>
  <#local value = assign.value>
  <#if value.arrayValue??>
    <#local origObjName = value.arrayValue.getLabelledOption("original","object")>
    <#local message = value.arrayValue.getLabelledOption("required", "message")!"">
    <#local origObj = model.findObjectByName(origObjName)>
${""?left_pad(indent)}// 查找【${modelbase.get_object_label(origObj)}】集合对象数据
${""?left_pad(indent)}${java.nameVariable(origObjName)}Query = new ${java.nameType(origObjName)}Query();
${""?left_pad(indent)}${java.nameVariable(origObjName)}Query.setLimit(-1);    
<#-- 设置查询条件 -->
<@print_unique_labels_setter varname=(origObjName+"Query") objval=value.arrayValue indent=indent />    
${""?left_pad(indent)}List<${java.nameType(origObjName)}Query> ${java.nameVariable(assign.assignee)} = new ArrayList<>();
${""?left_pad(indent)}Pagination<${java.nameType(origObjName)}Query> page${java.nameType(assign.assignee)} = ${java.nameVariable(origObjName)}Service.find${java.nameType(inflector.pluralize(origObjName))}(${java.nameVariable(origObjName)}Query);    
${""?left_pad(indent)}${java.nameVariable(assign.assignee)}.addAll(page${java.nameType(assign.assignee)}.getData());
${""?left_pad(indent)}if (page${java.nameType(assign.assignee)}.getData().isEmpty()) {
${""?left_pad(indent)}  throw new ServiceException(404, "${message}");
${""?left_pad(indent)}}
  <#elseif value.objectValue??>
    <#local origObjName = value.objectValue.getLabelledOption("original","object")>
    <#local message = value.objectValue.getLabelledOption("required", "message")!"">
    <#local origObj = model.findObjectByName(origObjName)>
    <#local origObjIdAttr = modelbase.get_id_attributes(origObj)?first>
${""?left_pad(indent)}// 查找【${modelbase.get_object_label(origObj)}】对象数据
${""?left_pad(indent)}${java.nameVariable(origObjName)}Query = new ${java.nameType(origObjName)}Query();
${""?left_pad(indent)}${java.nameVariable(origObjName)}Query.setLimit(-1); 
<#-- 设置查询条件 -->
<@print_unique_labels_setter varname=(origObjName+"Query") objval=value.objectValue indent=indent /> 
${""?left_pad(indent)}Pagination<${java.nameType(origObjName)}Query> page${java.nameType(inflector.pluralize(origObjName))} = ${java.nameVariable(origObjName)}Service.find${java.nameType(inflector.pluralize(origObjName))}(${java.nameVariable(origObjName)}Query);  
${""?left_pad(indent)}if (!page${java.nameType(inflector.pluralize(origObjName))}.getData().isEmpty()) {
${""?left_pad(indent)}  ${java.nameVariable(assign.assignee)} = page${java.nameType(inflector.pluralize(origObjName))}.getData().get(0);
    <#if usecase.getVariable(origObjName + "_" + origObjIdAttr.name)?? || usecase.getVariable(origObjIdAttr.name)??>
${""?left_pad(indent)}  ${modelbase.get_attribute_sql_name(origObjIdAttr)} = ${java.nameVariable(assign.assignee)}.${modelbase4java.name_getter(origObjIdAttr)}();
    </#if>
    <#if message != "">
${""?left_pad(indent)}} else {
${""?left_pad(indent)}  throw new ServiceException(404, "${message}");
    </#if>
${""?left_pad(indent)}}
  </#if>
</#macro>

<#macro print_statement_loop usecase stmt indent>
  <#local loop = stmt>
${""?left_pad(indent)}for (${java.nameType(loop.componentType.name)}Query ${java.nameVariable(loop.itemVar)} : ${java.nameVariable(loop.arrayVar)}) {
  <#list loop.statements as innerStmt>
<@print_statement usecase=usecase stmt=innerStmt indent=indent+2 />
  </#list>
${""?left_pad(indent)}}
</#macro>

<#macro print_statement_if usecase stmt indent>
${""?left_pad(indent)}// hello, this is if-statement
</#macro>

<#macro print_statements_for_value_array value indent>
  <#if value.arrayValue??>
    <#local origObjName = value.arrayValue.getLabelledOption("original","object")>
    <#local origObj = model.findObjectByName(origObjName)>
  </#if>
</#macro>

<#--
 ### Gets the code-generation ready default value literal for an attribute.
 ### <p>
 ### This function inspects the type of the default value (String, Number, Boolean)
 ### and formats it according to standard programming language syntax.
 ### For example, it wraps strings in double quotes.
 ###
 ### @param attrWithValue
 ###        the attribute definition object that holds the 'value' property
 ###
 ### @return
 ###        the formatted literal string (e.g., "null", "\"hello\"", "123", "true")
 -->
<#function get_attribute_default_value usecase attrWithValue>
  <#if !attrWithValue.value??>
    <#return "null">
  </#if>
  <#local value = attrWithValue.value>
  <#if value.string??>
    <#return "\"" + value.string + "\"">
  <#elseif value.number??>
    <#return value.number>
  <#elseif value.boolean??>
    <#return value.boolean>
  <#elseif value.keyword?? && value.keyword == "now">
    <#return "new java.sql.Timestamp(System.currentTimeMillis())">  
  <#elseif value.variable??>
    <#--  <#local varObj = usecase.getVariable(value.variable)>  -->
    <#return java.nameVariable(value.variable)>  
  </#if>  
  <#return "null">
</#function>

<#--
 ### Generates code to retrieve a single, unique object instance based on specific criteria
 ### and assigns it to a variable.
 ### <p>
 ### This macro handles the logic for "Reference Assignment". Instead of creating a new object,
 ### it looks up an existing entity using attributes defined in the "unique" label options.
 ### It automates the creation of a Query DTO, population of search criteria, service invocation,
 ### and optional existence validation.
 ###
 ### Logic Flow:
 ### 1. Identify the unique object type from "unique.object" label.
 ### 2. Construct a Query object (e.g., UserQuery).
 ### 3. Populate the Query object with values from the assignment source.
 ### 4. Call the Service layer to retrieve the object (e.g., userService.getUser(...)).
 ### 5. (Optional) Generate a null-check if the object is labeled "required".
 ###
 ### @param usecase
 ###        the current use case definition
 ### @param assign
 ###        the assignment statement node (containing assignee and value)
 ### @param indent
 ###        the indentation level for code generation
 -->
<#macro print_assignment_simple_for_object usecase assign indent>
  <#local objVal = assign.value.objectValue>
  <#-- [Step 1] 获取唯一性约束配置 -->
  <#-- 尝试获取 "unique" 标签下的 "object" 选项，这代表要查找的领域对象名称 -->
  <#local uniqueObjName = usebase.get_object_unique_object(objVal)>
  <#local sourceVarName = objVal.getLabelledOption("original", "source")!"">
  <#if uniqueObjName != "">
    <#--
     ### 如果没有定义 "unique.object"，则无法确定如何查找对象。
     ### 这种情况通常意味着元数据配置不完整，或者这不是一个查找赋值操作。
     ### 直接返回，不生成任何代码。
     -->
    <#local uniqueLabels = usebase.get_object_unique_labels(objVal)> 
    <#local uniqueAttrNames = objVal.getLabelledOptionAsList("unique", "attribute")>
${""?left_pad(indent)}// 准备查询条件: 根据唯一键查找 ${uniqueObjName}
${""?left_pad(indent)}unique${java.nameType(uniqueObjName)}Query = new ${java.nameType(uniqueObjName)}Query();
    <#list uniqueLabels as label>
      <#if !model.findAttributeByNames(uniqueObjName, label.attrname)??><#continue></#if>
      <#local uniqueAttr = model.findAttributeByNames(uniqueObjName, label.attrname)>
      <#if uniqueAttr.alias??>
${""?left_pad(indent)}unique${java.nameType(uniqueObjName)}Query.set${java.nameType(uniqueAttr.alias)}(${java.nameVariable(label.attrname)});
      <#elseif label.value == "now">
${""?left_pad(indent)}unique${java.nameType(uniqueObjName)}Query.${modelbase4java.name_setter(uniqueAttr)}(new java.sql.Timestamp(System.currentTimeMillis()));      
      <#elseif label.value == "true" || label.value == "false">
${""?left_pad(indent)}unique${java.nameType(uniqueObjName)}Query.${modelbase4java.name_setter(uniqueAttr)}(${label.value});      
      <#else>
${""?left_pad(indent)}unique${java.nameType(uniqueObjName)}Query.${modelbase4java.name_setter(uniqueAttr)}(${modelbase.get_attribute_sql_name(uniqueAttr)});        
      </#if>
    </#list>
${""?left_pad(indent)}${java.nameVariable(assign.assignee)} = ${java.nameVariable(uniqueObjName)}Service.get${java.nameType(uniqueObjName)}(unique${java.nameType(uniqueObjName)}Query); 
    <#if objVal.isLabelled("required")>    
${""?left_pad(indent)}// 校验对象是否存在
${""?left_pad(indent)}if (${java.nameVariable(assign.assignee)} == null) {
${""?left_pad(indent)}  throw new ServiceException(400, "${objVal.getLabelledOption("required", "message")}");
${""?left_pad(indent)}}
    </#if>   
  <#elseif sourceVarName != "">
    <#local sourceVar = usecase.getVariable(sourceVarName)>
    <#local sourceObj = sourceVar.type>
    <#local origObjName = objVal.getLabelledOption("original", "object")>
    <#--
     ### 直接从其他的变量作为数据源头，产生新的对象实例，
     ### 赋值给新实例。
     -->  
${""?left_pad(indent)}${java.nameVariable(assign.assignee)} = new ${java.nameType(origObjName)}Query();  
<@print_object_object_copy sourceObj=sourceObj sourceVarName=sourceVarName targetObj=model.findObjectByName(origObjName) targetVarName=java.nameVariable(assign.assignee) indent=indent />
${""?left_pad(indent)}${java.nameType(origObjName)}Query.setDefaultValues(${java.nameVariable(assign.assignee)}, true);
${""?left_pad(indent)}${java.nameVariable(origObjName)}Service.save${java.nameType(origObjName)}(${java.nameVariable(assign.assignee)});  
  </#if>
</#macro>

<#--
 ### Generates code for assigning values to an array/list variable.
 ### <p>
 ### This macro handles the transformation of a source collection into a target collection.
 ### It iterates through the source list defined by the "original.source" label,
 ### instantiates target objects, and populates the result list.
 ###
 ### Logic Flow:
 ### 1. Metadata Extraction: Identifies the source variable name and the target object type.
 ### 2. List Initialization: Generates code to create a new ArrayList for the result.
 ### 3. Iteration: Generates a for-loop to traverse the source collection.
 ### 4. Item Creation: Inside the loop, creates instances of the target object.
 ### 5. Attribute Mapping: Currently initializes attributes (logic shows setting to null, possibly a placeholder).
 ### 6. Collection Building: Adds the new item to the result list.
 ### 7. Unique/Lookup Preparation: (At the end) Prepares metadata for unique object lookups if configured.
 ###
 ### @param usecase
 ###        the current use case definition
 ### @param assign
 ###        the assignment statement node
 ### @param indent
 ###        the indentation level
 -->
<#macro print_assignment_simple_for_array usecase assign indent>
  <#local arrayValObj = assign.value.arrayValue>
  <#-- 获取源变量名 (例如: "&orders") -->
  <#local sourceVarName = arrayValObj.getLabelledOption("original","source")>
  <#local arrayValDataObj = model.findObjectByName(arrayValObj.getLabelledOption("original","object"))>
  <#local sourceVar = usecase.getVariable(sourceVarName)>
  <#local varComponentType = sourceVar.type.componentType.name>
<#-- TODO: 是否需要从可计算的属性中，衍生出其他集合属性 (保留原有的 TODO) -->
${""?left_pad(indent)}// 处理数组对象赋值: 从 ${sourceVarName} 转换列表
${""?left_pad(indent)}List<${java.nameType(arrayValDataObj.name)}Query> ${java.nameVariable(assign.assignee)} = new ArrayList<>();  
  <#if arrayValObj.getLabelledData("tabular_array")?? && 
       arrayValObj.getLabelledData("tabular_array").hasMoreArrays()>   
    <#local tabularArray = arrayValObj.getLabelledData("tabular_array")>
    <#local leftObj = tabularArray.mainObject>
    <#local leftVar = tabularArray.mainVariable>
    <#local leftAttr = tabularArray.compoundConditions[0].joinConditions[0].leftAttribute>
    <#local rightObj = tabularArray.compoundConditions[0].joinConditions[0].rightObject>
    <#local rightVar = tabularArray.compoundConditions[0].joinConditions[0].rightVariable>
    <#local rightAttr = tabularArray.compoundConditions[0].joinConditions[0].rightAttribute>
${""?left_pad(indent)}List<Map<String,Object>> ${tabularArray.mainVariable}JoinedResult = Datasets.leftJoin(
${""?left_pad(indent)}    ${java.nameVariable(leftVar)}, ${java.nameVariable(rightVar)}, 
${""?left_pad(indent)}    ${java.nameType(leftObj.name)}Query::${modelbase4java.name_getter(leftAttr)},
${""?left_pad(indent)}    ${java.nameType(rightObj.name)}Query::${modelbase4java.name_getter(rightAttr)},
${""?left_pad(indent)}    (u,o) -> {
${""?left_pad(indent)}      Map<String,Object> m = Datasets.beanToMap(u);
${""?left_pad(indent)}      if (o != null) m.putAll(Datasets.beanToMap(o));
${""?left_pad(indent)}      return m;
${""?left_pad(indent)}    });
${""?left_pad(indent)}for (Map<String,Object> row : ${java.nameVariable(sourceVarName)}JoinedResult) {
${""?left_pad(indent)}  ${java.nameType(arrayValDataObj.name)}Query item = new ${java.nameType(arrayValDataObj.name)}Query();
<@print_map_object_copy sourceObj=model.findObjectByName(varComponentType) sourceVarName="row" targetObj=arrayValDataObj targetVarName="item" indent=indent+2 />
  <#else>
${""?left_pad(indent)}for (${java.nameType(varComponentType)}Query row : ${java.nameVariable(sourceVarName)}) {
${""?left_pad(indent)}  ${java.nameType(arrayValDataObj.name)}Query item = new ${java.nameType(arrayValDataObj.name)}Query();
<@print_object_object_copy sourceObj=model.findObjectByName(varComponentType) sourceVarName="row" targetObj=arrayValDataObj targetVarName="item" indent=indent+2 />
  </#if>
  <#list arrayValObj.attributes as attr>
    <#local attrInDataObj = arrayValDataObj.getAttribute(attr.name)>
    <#-- 
     ### 注意：此处代码目前生成 set...(null)。
     ### 通常这里应该生成类似 item.setXxx(row.getXxx()) 的代码。
     ### 如果是刻意置空，说明是初始化；如果是待实现，建议检查此处逻辑。
     -->
    <#if attr.value??>
<@print_attribute_set_for_value loopVar="row" objVar="item" attrInDataObj=attrInDataObj value=attr.value indent=indent+2 />
    <#else>
${""?left_pad(indent)}  item.set${java.nameType(modelbase.get_attribute_sql_name(attrInDataObj))}(null); 
    </#if>
  </#list>
${""?left_pad(indent)}  ${java.nameType(arrayValDataObj.name)}Query.setDefaultValues(item, true);  
${""?left_pad(indent)}  ${java.nameVariable(arrayValDataObj.name)}Service.save${java.nameType(arrayValDataObj.name)}(item);    
${""?left_pad(indent)}  ${java.nameVariable(assign.assignee)}.add(item);
${""?left_pad(indent)}}  
  <#-- 唯一性/引用查找元数据准备 (逻辑似乎未完结) -->
  <#local arrVal = assign.value.arrayValue>
  <#local uniqueObjName = arrVal.getLabelledOption("unique", "object")!"">
  <#if uniqueObjName == "">
    <#return>
  </#if>
  <#local uniqueAttrNames = arrVal.getLabelledOptionAsList("unique", "attribute")>
  <#-- 此处宏结束，后续可能利用 uniqueObjName 和 uniqueAttrNames 生成查找逻辑 -->
</#macro>

<#--
 ### 根据 DSL 解析出的值类型，生成目标对象的属性赋值代码（Setter）。
 ### <p>
 ### 该宏主要用于处理语句中的具体“值（Value）”，并将其安全地赋给目标 Java 对象。
 ### 支持的值类型包括：字面量（String, Number, Boolean）、上下文变量引用，以及最复杂的计算表达式（calcExpr）。
 ###
 ### 特别说明 (calcExpr):
 ### 当值是一个公式时（如：amount = usage * rate），该宏会负责解析公式中的操作数（operands）。
 ### 如果操作数关联了外部实体（如需要查数据库获取 rate），宏会自动生成构建 Query 并调用 Service 查找该实体的代码。
 ###
 ### @param loopVar
 ###        当前上下文的源变量名（如果是循环内部，通常是 "row" 或 "item"）
 ### @param objVar
 ###        被赋值的目标对象变量名
 ### @param attrInDataObj
 ###        目标对象中的属性定义对象
 ### @param value
 ###        DSL 语法树解析出的值对象 (AST Node)
 ### @param indent
 ###        代码缩进级别
 -->
<#macro print_attribute_set_for_value loopVar objVar attrInDataObj value indent>
  <#if value.string??>
${""?left_pad(indent)}${objVar}.set${java.nameType(modelbase.get_attribute_sql_name(attrInDataObj))}("${value.string}");
  <#elseif value.number??>
${""?left_pad(indent)}${objVar}.set${java.nameType(modelbase.get_attribute_sql_name(attrInDataObj))}(new BigDecimal("${value.number}"));
  <#elseif value.boolean??>
${""?left_pad(indent)}${objVar}.set${java.nameType(modelbase.get_attribute_sql_name(attrInDataObj))}(${value.boolean});
  <#elseif value.variable??>
    <#local strs = value.variable?split(".")>
    <#local varObj = usecase.getVariable(strs[0])>
    <#if varObj.componentType??>
      <#local compObj = varObj.componentType>
    <#else>
      <#local compObj = varObj.type>
    </#if>  
    <#local valueAttrInCompObj = compObj.getAttribute(strs[1])>
      <#if varObj.componentType?? && compObj.name == attrInDataObj.parent.name>
      <#-- 集合对象中的属性，并且是首个对象中的属性 -->
${""?left_pad(indent)}${objVar}.set${java.nameType(modelbase.get_attribute_sql_name(attrInDataObj))}(${loopVar}.get${java.nameType(modelbase.get_attribute_sql_name(valueAttrInCompObj))}());
      <#elseif varObj.componentType??>
      <#-- 集合对象中的属性，不是首个对象中的属性 -->
${""?left_pad(indent)}${objVar}.set${java.nameType(modelbase.get_attribute_sql_name(attrInDataObj))}((${modelbase4java.type_attribute_primitive(valueAttrInCompObj)})${loopVar}.get("${modelbase.get_attribute_sql_name(valueAttrInCompObj)}")); 
      <#else>
      <#-- 非集合对象中的属性 -->
${""?left_pad(indent)}${objVar}.set${java.nameType(modelbase.get_attribute_sql_name(attrInDataObj))}(${java.nameVariable(strs[0])}.${modelbase4java.name_getter(valueAttrInCompObj)}());              
      </#if>
  <#elseif value.calcExpr??>
    <#-- TODO: 表达式处理，核心中的核心 -->
${""?left_pad(indent)}// 处理计算表达式：${value.originalText}
    <#local operands = value.calcExpr.operands>
    <#list operands as operand>
      <#local originalObjName = operand.objectValue.getLabelledOption("original", "object")>
      <#local operandUniques = usebase.get_operand_unique_labels(operand)>
${""?left_pad(indent)}${java.nameVariable(originalObjName)}Query = new ${java.nameType(originalObjName)}Query();
      <#list operandUniques as operandUnique>
        <#if operandUnique.attrtype == operandUnique.value>
${""?left_pad(indent)}${java.nameVariable(originalObjName)}Query.set${java.nameType(operandUnique.attrname)}(row.get${java.nameType(operandUnique.value)}());
        <#elseif operandUnique.attrtype == operandUnique.attrname>
${""?left_pad(indent)}${java.nameVariable(originalObjName)}Query.set${java.nameType(operandUnique.attrname)}(row.get${java.nameType(operandUnique.attrname)}());        
        <#else>
          <#if operandUnique.attrtype == "string">
${""?left_pad(indent)}${java.nameVariable(originalObjName)}Query.set${java.nameType(operandUnique.attrname)}("${operandUnique.value}");
          <#elseif operandUnique.attrtype == "number">
${""?left_pad(indent)}${java.nameVariable(originalObjName)}Query.set${java.nameType(operandUnique.attrname)}(new BigDecimal("${operandUnique.value}"));
          <#elseif operandUnique.attrtype == "boolean">
${""?left_pad(indent)}${java.nameVariable(originalObjName)}Query.set${java.nameType(operandUnique.attrname)}(${operandUnique.value});
          </#if>
        </#if>
      </#list> 
${""?left_pad(indent)}${java.nameType(originalObjName)}Query found${java.nameType(originalObjName)} = ${java.nameVariable(originalObjName)}Service.get${java.nameType(originalObjName)}(${java.nameVariable(originalObjName)}Query);       
    </#list>
${""?left_pad(indent)}// TODO: 开始计算${modelbase.get_attribute_sql_name(attrInDataObj)}
${""?left_pad(indent)}${objVar}.set${java.nameType(modelbase.get_attribute_sql_name(attrInDataObj))}(null);
  <#else>
${""?left_pad(indent)}${objVar}.set${java.nameType(modelbase.get_attribute_sql_name(attrInDataObj))}(null);
  </#if>
</#macro>

<#--
 ### 生成对象到对象（Object-to-Object）的属性拷贝代码。
 ### <p>
 ### 该宏充当硬编码的 BeanMapper / Assembler。它遍历源对象和目标对象的属性，
 ### 当发现两边拥有相同的属性名（基于 SQL Name）且类型兼容时，自动生成 `target.setX(source.getX())` 的代码。
 ###
 ### 优势: 相比于运行时的反射（如 Spring BeanUtils），这种生成期的硬编码拷贝具有最佳的执行性能。
 ###
 ### @param sourceObj
 ###        源对象定义 (ObjectDefinition)
 ### @param sourceVarName
 ###        源对象的 Java 变量名
 ### @param targetObj
 ###        目标对象定义 (ObjectDefinition)
 ### @param targetVarName
 ###        目标对象的 Java 变量名
 ### @param indent
 ###        代码缩进级别
 -->
<#macro print_object_object_copy sourceObj sourceVarName targetObj targetVarName indent>
  <#list sourceObj.attributes as sourceAttr>
    <#if modelbase.is_attribute_system(sourceAttr)><#continue></#if>
    <#local sourceAttrSqlName = modelbase.get_attribute_sql_name(sourceAttr)>
    <#list targetObj.attributes as targetAttr>
      <#local targetAttrSqlName = modelbase.get_attribute_sql_name(targetAttr)>
      <#if targetAttr.type.primitive>
        <#if sourceAttrSqlName == targetAttrSqlName && sourceAttr.type.name == targetAttr.type.name>
${""?left_pad(indent)}${java.nameVariable(targetVarName)}.set${java.nameType(modelbase.get_attribute_sql_name(targetAttr))}(${java.nameVariable(sourceVarName)}.get${java.nameType(modelbase.get_attribute_sql_name(sourceAttr))}());      
          <#break>  
        </#if>
      <#elseif targetAttr.type.custom>
        <#if sourceAttrSqlName == targetAttrSqlName>
${""?left_pad(indent)}${java.nameVariable(targetVarName)}.set${java.nameType(modelbase.get_attribute_sql_name(targetAttr))}(${java.nameVariable(sourceVarName)}.get${java.nameType(modelbase.get_attribute_sql_name(sourceAttr))}());      
          <#break>  
        </#if>
      </#if>
    </#list>
  </#list>
</#macro>

<#--
 ### 生成 Map 到对象（Map-to-Object）的属性装配代码。
 ### <p>
 ### 该宏通常用于数据访问层（DAO）或原生 SQL 结果集的处理。它将一个 `Map<String, Object>` 
 ### 中的键值对安全地取出、强制类型转换，并 set 到目标的 Java 对象中。
 ###
 ### 核心逻辑:
 ### `target.setField( (FieldType) map.get("field_name") );`
 ###
 ### @param sourceObj
 ###        用于提供属性参照的源对象定义
 ### @param sourceVarName
 ###        源 Map 对象的 Java 变量名 (如 'row')
 ### @param targetObj
 ###        目标对象定义 (ObjectDefinition)
 ### @param targetVarName
 ###        目标对象的 Java 变量名
 ### @param indent
 ###        代码缩进级别
 -->
<#macro print_map_object_copy sourceObj sourceVarName targetObj targetVarName indent>
  <#list sourceObj.attributes as sourceAttr>
    <#if modelbase.is_attribute_system(sourceAttr)><#continue></#if>
    <#local sourceAttrSqlName = modelbase.get_attribute_sql_name(sourceAttr)>
    <#list targetObj.attributes as targetAttr>
      <#local targetAttrSqlName = modelbase.get_attribute_sql_name(targetAttr)>
      <#if targetAttr.type.primitive>
        <#if sourceAttrSqlName == targetAttrSqlName && sourceAttr.type.name == targetAttr.type.name>
${""?left_pad(indent)}${java.nameVariable(targetVarName)}.set${java.nameType(modelbase.get_attribute_sql_name(targetAttr))}((${modelbase4java.type_attribute_primitive(targetAttr)})${java.nameVariable(sourceVarName)}.get("${java.nameType(modelbase.get_attribute_sql_name(sourceAttr))}"));      
          <#break>  
        </#if>
      <#elseif targetAttr.type.custom>
        <#if sourceAttrSqlName == targetAttrSqlName>
${""?left_pad(indent)}${java.nameVariable(targetVarName)}.set${java.nameType(modelbase.get_attribute_sql_name(targetAttr))}((${modelbase4java.type_attribute_primitive(targetAttr)})${java.nameVariable(sourceVarName)}.get("${java.nameType(modelbase.get_attribute_sql_name(sourceAttr))}"));      
          <#break>  
        </#if>
      </#if>
    </#list>
  </#list>
</#macro>

<#--
 ### 生成唯一性约束或查找条件的属性赋值代码 (Setter)。
 ### <p>
 ### 该宏遍历对象值定义中的 "unique" 标签，这些标签通常代表用于数据库查找的唯一键（Unique Keys）。
 ### 宏会解析标签中的值（可能是字面量、变量引用或静态属性），并生成相应的 Java Setter 代码
 ### 将这些值设置到目标变量（varname，通常是 Query 对象）中。
 ###
 ### 逻辑流程 (Logic Flow):
 ### 1. 提取标签: 获取对象上的 unique 标签列表。
 ### 2. 解析元数据:
 ###    - 解析目标属性 (objAttr)。
 ###    - 尝试解析源值：可能是静态属性定义 (attrval) 或 上下文变量 (varObj)。
 ### 3. 生成赋值代码 (由类型决定):
 ###    - String 字面量: 生成带引号的赋值。
 ###    - Number 字面量: 生成数字赋值，智能处理 Long 类型后缀。
 ###    - 变量引用 (Variable):
 ###        - 集合类型: 生成循环代码，调用 `addXxx` 方法 (用于构建 `IN` 查询)。
 ###        - 单对象类型: 生成 `setXxx(var.getYyy())` 代码。
 ###    - 静态引用: 生成常量或枚举值的赋值。
 ###
 ### @param varname
 ###        目标 Java 变量名 (例如 "userQuery")
 ### @param objval
 ###        包含唯一性配置的源对象值定义
 ### @param indent
 ###        代码缩进级别
 -->
<#macro print_unique_labels_setter varname objval indent>
  <#local uniqueLabels = usebase.get_object_unique_labels(objval)>
  <#list uniqueLabels as label>
    <#local objname = label.objname>
    <#local attrname = label.attrname>
    <#local attrtype = label.attrtype>
    <#local value = label.value>
    <#local objAttr = modelbase.find_attribute_by_names(objname, attrname)!"">
    <#local attrval = model.findAttributeByNames(attrtype, value)!"">
    <#local varObj = "">
    <#if attrval == "">
      <#local varObj = usecase.getVariable(attrtype)!"">
    </#if>
    <#if attrtype == "string"><#-- 字符串常量作为值 -->
${""?left_pad(indent)}${java.nameVariable(varname)}.${modelbase4java.name_setter(objAttr)}("${label.value}");              
    <#elseif attrtype == "number"><#-- 数字常量作为值 -->
      <#if modelbase4java.type_attribute_primitive(objAttr) == "Long">
${""?left_pad(indent)}${java.nameVariable(varname)}.${modelbase4java.name_setter(objAttr)}(${label.value}L); 
      <#else>
${""?left_pad(indent)}${java.nameVariable(varname)}.${modelbase4java.name_setter(objAttr)}(${label.value});       
      </#if>
    <#elseif varObj != ""><#-- usecase中注册的变量作为值 -->
      <#if varObj.type.collection>
        <#local compObj = varObj.type.componentType>
        <#local valueAsDataAttr = model.findAttributeByNames(compObj.name, value)>
${""?left_pad(indent)}for (${java.nameType(compObj.name)}Query row : ${java.nameVariable(attrtype)}) {
${""?left_pad(indent)}  ${java.nameVariable(varname)}.add${java.nameType(modelbase.get_attribute_sql_name(objAttr))}(row.${modelbase4java.name_getter(valueAsDataAttr)}()); 
${""?left_pad(indent)}}
      <#else>
        <#local valueAsDataAttr = model.findAttributeByNames(varObj.type.name, value)!"">
        <#if valueAsDataAttr != "">
${""?left_pad(indent)}${java.nameVariable(varname)}.${modelbase4java.name_setter(objAttr)}(${java.nameVariable(varObj.name)}.${modelbase4java.name_getter(valueAsDataAttr)}());
        </#if> 
      </#if>       
    <#elseif attrval != ""><#-- FIXME: 显示引用的属性作为值（描述不准确）-->
${""?left_pad(indent)}${java.nameVariable(varname)}.${modelbase4java.name_setter(objAttr)}(${modelbase.get_attribute_sql_name(attrval)}); 
    <#elseif attrtype == value><#-- NOTE -->
      <#local strs = attrtype?split(".")>
      <#if strs?size == 1>
${""?left_pad(indent)}${java.nameVariable(varname)}.${modelbase4java.name_setter(objAttr)}(${modelbase.get_attribute_sql_name(objAttr)}());   
      <#else>
        <#if usecase.getVariable(strs[0])??>
          <#local varObj = usecase.getVariable(strs[0])>
          <#local valueAttr = modelbase.find_attribute_by_names(varObj.type.name, strs[1])>
${""?left_pad(indent)}${java.nameVariable(varname)}.${modelbase4java.name_setter(objAttr)}(${java.nameVariable(strs[0])}.${modelbase4java.name_getter(valueAttr)}());     
        <#else>
${""?left_pad(indent)}${java.nameVariable(varname)}.${modelbase4java.name_setter(objAttr)}(${java.nameVariable(strs[0])}.${modelbase4java.name_getter(objAttr)}());  
        </#if>       
      </#if>     
    <#elseif objAttr != ""><#-- FIXME: 隐式引用的属性作为值（描述不准确） -->
${""?left_pad(indent)}${java.nameVariable(varname)}.${modelbase4java.name_setter(objAttr)}(${modelbase.get_attribute_sql_name(objAttr)});    
    </#if>     
  </#list>
</#macro>

<#--
 ### 扫描用例涉及的所有领域对象，并生成 Service 依赖注入字段 (@Inject)。
 ### <p>
 ### 该宏用于分析 UseCase 的整体结构，识别出所有需要交互的领域对象，并自动注入对应的 Service。
 ### 识别范围包括：
 ### 1. 直接引用: 语句中直接操作的对象。
 ### 2. 聚合链: 返回值对象结构中涉及的聚合对象（如主从表、统计对象）。
 ### 3. 关联链: 输入参数到返回值之间路径上的中间对象。
 ###
 ### @param usecase
 ###        当前用例定义对象
 ### @param indent
 ###        代码缩进级别
 -->
<#macro print_services_for_usecase usecase indent>
  <#local printedObjs = {}>
  <#local usingDirectDataObjs = usecase.getDataObjects()>
  <#list usingDirectDataObjs as dataObj>
    <#local printedObjs += {dataObj.name:dataObj.name}>

${""?left_pad(indent)}@Inject
${""?left_pad(indent)}private ${java.nameType(dataObj.name)}Service ${java.nameVariable(dataObj.name)}Service;
  </#list>
  <#local aggregateChain = aggregateBuilder.build(usecase.returnedObject)>
  <#local objRelsList = aggregateChain.build()>
  <#list aggregateChain.getObjects() as obj>
    <#if printedObjs[obj.name]??><#continue></#if>
    <#local printedObjs += {obj.name:obj.name}>

${""?left_pad(indent)}@Inject
${""?left_pad(indent)}private ${java.nameType(obj.name)}Service ${java.nameVariable(obj.name)}Service;
  </#list>
  <#---------------------------------->
  <#-- 参数和返回值关联对象需要的服务对象 -->
  <#---------------------------------->
  <#local associationChain = associationBuilder.build(usecase.parameterizedObject, usecase.returnedObject)>
  <#local objSize = associationChain.getAssociatingObjects()?size>
  <#if (objSize > 2)>
    <#list 1..(objSize-2) as index>
      <#local obj = associationChain.getAssociatingObjects()[index]>
      <#if printedObjs[obj.name]??><#continue></#if>
      <#local printedObjs += {obj.name:obj.name}>

${""?left_pad(indent)}@Inject
${""?left_pad(indent)}private ${java.nameType(obj.name)}Service ${java.nameVariable(obj.name)}Service;
    </#list>
  </#if>
</#macro>

<#--
 ### 扫描用例涉及的所有领域对象，并生成 Query 变量声明代码。
 ### <p>
 ### 该宏与 `print_services_for_usecase` 逻辑类似，用于预先声明所需的 Query 对象变量。
 ### 通常用于方法体开头，或者测试用例的准备阶段。
 ###
 ### 逻辑流程:
 ### 1. 扫描直接使用对象。
 ### 2. 扫描聚合链对象。
 ### 3. 扫描关联链中间对象。
 ###
 ### @param usecase
 ###        当前用例定义对象
 ### @param indent
 ###        代码缩进级别
 -->
<#macro print_variables_for_usecase usecase indent>
  <#local printedObjs = {}>
  <#local usingDirectDataObjs = usecase.getDataObjects()>
  <#list usingDirectDataObjs as dataObj>
    <#local printedObjs += {dataObj.name:dataObj.name}>
${""?left_pad(indent)}${java.nameType(dataObj.name)}Query ${java.nameVariable(dataObj.name)}Query = null;
${""?left_pad(indent)}${java.nameType(dataObj.name)}Query ${java.nameVariable(dataObj.name)} = null;
${""?left_pad(indent)}${java.nameType(dataObj.name)}Query unique${java.nameType(dataObj.name)}Query = null;
  </#list>
  <#local aggregateChain = aggregateBuilder.build(usecase.returnedObject)>
  <#local objRelsList = aggregateChain.build()>
  <#list aggregateChain.getObjects() as obj>
    <#if printedObjs[obj.name]??><#continue></#if>
    <#local printedObjs += {obj.name:obj.name}>
${""?left_pad(indent)}${java.nameType(obj.name)}Query ${java.nameVariable(obj.name)}Query = null;
${""?left_pad(indent)}${java.nameType(obj.name)}Query ${java.nameVariable(obj.name)} = null;
${""?left_pad(indent)}${java.nameType(obj.name)}Query unique${java.nameType(obj.name)}Query = null;
  </#list>
  <#---------------------------------->
  <#-- 参数和返回值关联对象需要的服务对象 -->
  <#---------------------------------->
  <#local associationChain = associationBuilder.build(usecase.parameterizedObject, usecase.returnedObject)>
  <#local objSize = associationChain.getAssociatingObjects()?size>
  <#if (objSize > 2)>
    <#list 1..(objSize-2) as index>
      <#local obj = associationChain.getAssociatingObjects()[index]>
      <#if printedObjs[obj.name]??><#continue></#if>
      <#local printedObjs += {obj.name:obj.name}>
${""?left_pad(indent)}${java.nameType(obj.name)}Query ${java.nameVariable(obj.name)}Query = null;
${""?left_pad(indent)}${java.nameType(obj.name)}Query ${java.nameVariable(obj.name)} = null;
${""?left_pad(indent)}${java.nameType(obj.name)}Query unique${java.nameType(obj.name)}Query = null;
    </#list>
  </#if>
  <#list usecase.statements as stmt>
    <#if stmt.assignee??>
      <#if printedObjs[stmt.assignee]??><#continue></#if>
      <#if stmt.value.objectValue??>
        <#local origObjName = stmt.value.objectValue.getLabelledOption("original", "object")>
${""?left_pad(indent)}${java.nameType(origObjName)}Query ${java.nameVariable(stmt.assignee)} = null;  
      </#if>    
    </#if>
  </#list>
</#macro>
