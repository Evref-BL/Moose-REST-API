"
I execute GraphQL requests against a GQLSchema.

	(GQLExecutor new schema: aSchema)
		execute: '{ hello }' operationName: nil variables: nil context: nil.

The answer is always an OrderedDictionary with 'data' and/or 'errors' (an Array of JSON-ready Dictionaries), following the GraphQL specification response format. Pre-execution errors (syntax, operation selection, variable coercion) produce a response without 'data'. Field errors are recorded with their path and locations, and nulls are propagated up to the nearest nullable field.

Optional settings: rootValue (source of root fields resolvers), maxListSize (cap on the number of list items completed).
"
Class {
	#name : 'GQLExecutor',
	#superclass : 'Object',
	#instVars : [
		'schema',
		'rootValue',
		'maxListSize',
		'context'
	],
	#category : 'GraphQL-Core-Execution',
	#package : 'GraphQL-Core',
	#tag : 'Execution'
}

{ #category : 'directives' }
GQLExecutor class >> excludingConditions [
	"Directive name -> value of its if: argument that excludes the selection (@skip(if: true), @include(if: false))"

	^ Dictionary new
		  at: 'skip' put: true;
		  at: 'include' put: false;
		  yourself
]

{ #category : 'instance creation' }
GQLExecutor class >> schema: aGQLSchema [
	^ self new schema: aGQLSchema; yourself
]

{ #category : 'private - errors' }
GQLExecutor >> addRequestError: aMessage nodes: aNodeCollection [
	"Record a request (pre-execution) error"
	^ context addError: (GQLError message: aMessage path: nil locations: (self locationsOf: aNodeCollection))
]

{ #category : 'private - executing' }
GQLExecutor >> argumentNodeNamed: aName in: aField [
	"Answer the value node given in the query for the argument aName of aField, nil if absent"

	^ aField arguments ifNotNil: [ :nodes |
		  nodes at: aName ifAbsent: [ nil ] ]
]

{ #category : 'private - executing' }
GQLExecutor >> basicExecute: aQueryString operationName: anOperationNameOrNil variables: aDictionaryOrNil context: anObject [
	| document operation data |
	aQueryString isEmptyOrNil ifTrue: [ ^ self errorResponseWithMessage: 'Must provide query string.' ].
	document := [ GQLParser parse: aQueryString asString ]
		on: GQLSyntaxError
		do: [ :e | ^ self syntaxErrorResponse: e ].
	context := GQLExecutionContext new.
	context
		schema: schema;
		document: document;
		fragments: document fragments;
		userContext: anObject;
		rootValue: rootValue.
	maxListSize ifNotNil: [ :size | context maxListSize: size ].
	operation := self selectOperationNamed: anOperationNameOrNil in: document.
	operation ifNil: [ ^ self errorsResponse ].
	context operation: operation.
	context variables: (self coerceVariableValues: aDictionaryOrNil).
	context hasErrors ifTrue: [ ^ self errorsResponse ].
	data := self executeOperation: operation.
	^ self responseWithData: data
]

{ #category : 'private - executing' }
GQLExecutor >> checkSelectionOf: aFieldDefinition fields: aFieldCollection path: aPath [
	"Leaf fields must not have sub-selections, composite (object or interface) fields must have one"

	| namedType fieldName |
	namedType := aFieldDefinition type namedType.
	fieldName := aFieldCollection first name asString.
	(namedType isLeaf and: [
		 aFieldCollection anySatisfy: [ :each | each selectionSet notNil ] ])
		ifTrue: [
				^ self
					  staticFieldError:
						  'Field "' , fieldName
						  , '" must not have a selection since type "'
						  , aFieldDefinition type printString , '" has no subfields.'
					  fields: aFieldCollection
					  path: aPath ].
	(namedType isComposite and: [
		 aFieldCollection allSatisfy: [ :each | each selectionSet isNil ] ])
		ifTrue: [
				^ self
					  staticFieldError: 'Field "' , fieldName , '" of type "'
						  , aFieldDefinition type printString
						  , '" must have a selection of subfields.'
					  fields: aFieldCollection
					  path: aPath ]
]

{ #category : 'private - executing' }
GQLExecutor >> coerceArgument: anArgument named: aName fields: aFieldCollection path: aPath [
	"Answer the value of anArgument: the value given in the query (a literal or a provided variable), coerced against
	the argument type, otherwise its default value"

	| node value |
	node := self argumentNodeNamed: aName in: aFieldCollection first.
	value := (node notNil and: [ node hasValueIn: context variables ])
		         ifTrue: [ node valueWithVariables: context variables ]
		         ifFalse: [
				         anArgument hasDefault ifFalse: [
						         ^ self
							           missingArgument: anArgument
							           named: aName
							           fields: aFieldCollection
							           path: aPath ].
				         anArgument defaultValue ].
	(value isNil and: [ anArgument type isNonNull ]) ifTrue: [
			^ self
				  fieldError: 'Argument "' , aName , '" of non-null type "'
					  , anArgument type printString , '" must not be null.'
				  fields: aFieldCollection
				  path: aPath ].
	node ifNil: [ ^ value ].
	^ self
		  coerceArgumentValue: value
		  of: anArgument
		  named: aName
		  node: node
		  fields: aFieldCollection
		  path: aPath
]

{ #category : 'private - executing' }
GQLExecutor >> coerceArgumentValue: aValue of: anArgument named: aName node: aValueNode fields: aFieldCollection path: aPath [
	"Coerce a value given in the query against the argument type; an invalid value is a field error"

	| failure coerced |
	coerced := [ self coerceInputValue: aValue type: anArgument type ]
		           on: GQLCoercionError
		           do: [ :e |
				           failure := e.
				           nil ].
	failure ifNotNil: [
			self
				fieldError:
					'Argument "' , aName , '" has invalid value '
					, (self describeValue:
							 (aValueNode valueWithVariables: context variables)) , '; '
					, (self messageForException: failure)
				fields: aFieldCollection
				path: aPath ].
	^ coerced
]

{ #category : 'private - executing' }
GQLExecutor >> coerceArgumentsOf: aFieldDefinition fields: aFieldCollection path: aPath [
	"Answer a Dictionary argument name (String) -> coerced value for all the arguments defined by aFieldDefinition.
	Arguments given in the query but not defined are ignored"

	| args |
	args := Dictionary new.
	aFieldDefinition arguments keysAndValuesDo: [ :argName :argument |
			args at: argName put: (self
					 coerceArgument: argument
					 named: argName
					 fields: aFieldCollection
					 path: aPath) ].
	^ args
]

{ #category : 'private - coercion' }
GQLExecutor >> coerceInputValue: aValue type: aType [
	"Coerce an input value (variable or argument) against aType (double dispatch). Signal GQLCoercionError on invalid values"

	^ aType coerceInputValue: aValue executor: self
]

{ #category : 'private - coercion' }
GQLExecutor >> coerceListInputValue: aValue type: aListType [
	"A single value given for a list type is coerced as a list of one item"

	(self isListValue: aValue) ifFalse: [
		^ Array with: (self coerceInputValue: aValue type: aListType ofType) ].
	^ Array streamContents: [ :stream |
			  aValue do: [ :each |
				  stream nextPut:
					  (self coerceInputValue: each type: aListType ofType) ] ]
]

{ #category : 'private - variables' }
GQLExecutor >> coerceVariable: aVariableDefinition from: aProvidedDictionary into: aResultDictionary [
	"Store in aResultDictionary the coerced value of the variable, provided or given by its default value; errors are recorded in the context"

	| name type value coerced failure |
	name := aVariableDefinition name asString.
	type := self
		        inputTypeOfVariable: aVariableDefinition
		        ifInvalid: [ ^ self ].
	value := aProvidedDictionary at: name ifAbsent: [
			         aVariableDefinition defaultValue
				         ifNil: [
				         ^ self missingVariable: aVariableDefinition type: type ]
				         ifNotNil: [ :node | node valueWithVariables: nil ] ].
	(value isNil and: [ type isNonNull ]) ifTrue: [
			^ self
				  addRequestError:
					  'Variable "$' , name , '" of non-null type "'
					  , type printString , '" must not be null.'
				  nodes: { aVariableDefinition } ].
	coerced := [ self coerceInputValue: value type: type ]
		           on: GQLCoercionError
		           do: [ :e |
				           failure := e.
				           nil ].
	failure ifNotNil: [
			^ self
				  addRequestError: 'Variable "$' , name , '" got invalid value '
					  , (self describeValue: value) , '; '
					  , (self messageForException: failure)
				  nodes: { aVariableDefinition } ].
	aResultDictionary at: name put: coerced
]

{ #category : 'private - variables' }
GQLExecutor >> coerceVariableValues: aDictionaryOrNil [
	"Answer a Dictionary of coerced variable values for the operation variable definitions; errors are recorded in the context"

	| provided result |
	provided := Dictionary new.
	aDictionaryOrNil isDictionary ifTrue: [
			aDictionaryOrNil keysAndValuesDo: [ :key :value |
				provided at: key asString put: value ] ].
	result := Dictionary new.
	context operation variableDefinitions do: [ :definition |
		self coerceVariable: definition from: provided into: result ].
	^ result
]

{ #category : 'private - fields collection' }
GQLExecutor >> collectFields: anObjectType selectionSet: aSelectionSet visited: aVisitedSet into: aGroupedDictionary path: aPath [
	"Double dispatch on each included selection (field, inline fragment or fragment spread)"

	aSelectionSet selections
		select: [ :selection | self shouldInclude: selection ]
		thenDo: [ :selection |
				selection
					collectFieldsFor: anObjectType
					visited: aVisitedSet
					into: aGroupedDictionary
					path: aPath
					executor: self ]
]

{ #category : 'private - fields collection' }
GQLExecutor >> collectFields: anObjectType selectionSets: aCollection path: aPath [
	"Answer an OrderedDictionary responseKey -> OrderedCollection of GQLField, applying directives and fragments"
	| grouped visited |
	grouped := OrderedDictionary new.
	visited := Set new.
	aCollection do: [ :selectionSet |
		selectionSet ifNotNil: [
			self
				collectFields: anObjectType
				selectionSet: selectionSet
				visited: visited
				into: grouped
				path: aPath ] ].
	^ grouped
]

{ #category : 'private - fields collection' }
GQLExecutor >> collectFragmentSpread: aFragmentSpread objectType: anObjectType visited: aVisitedSet into: aGroupedDictionary path: aPath [

	| fragment |
	(aVisitedSet includes: aFragmentSpread name) ifTrue: [ ^ self ].
	aVisitedSet add: aFragmentSpread name.
	fragment := context fragments
		            at: aFragmentSpread name
		            ifAbsent: [
		            ^ self unknownFragment: aFragmentSpread path: aPath ].
	(self typeCondition: fragment typeCondition appliesTo: anObjectType)
		ifFalse: [ ^ self ].
	self
		collectFields: anObjectType
		selectionSet: fragment selectionSet
		visited: aVisitedSet
		into: aGroupedDictionary
		path: aPath
]

{ #category : 'private - fields collection' }
GQLExecutor >> collectInlineFragment: anInlineFragment objectType: anObjectType visited: aVisitedSet into: aGroupedDictionary path: aPath [

	(self
		 typeCondition: anInlineFragment typeCondition
		 appliesTo: anObjectType) ifFalse: [ ^ self ].
	self
		collectFields: anObjectType
		selectionSet: anInlineFragment selectionSet
		visited: aVisitedSet
		into: aGroupedDictionary
		path: aPath
]

{ #category : 'private - completion' }
GQLExecutor >> completeAbstractValue: anAbstractType fields: aFieldCollection result: aResult path: aPath [
	"Determine the concrete object type of aResult, a value of anAbstractType (interface), and complete it as an object of that type.
	Record a field error if the type cannot be resolved or is not a possible type of anAbstractType"

	| failure runtimeType |
	runtimeType := [
		               schema
			               runtimeTypeOf: aResult
			               abstractType: anAbstractType
			               context: context userContext ]
		               on: Error
		               do: [ :e |
				               failure := e.
				               nil ].
	failure ifNotNil: [
			^ self
				  fieldError: (self messageForException: failure)
				  fields: aFieldCollection
				  path: aPath ].
	runtimeType ifNil: [
			^ self
				  fieldError: 'Abstract type "' , anAbstractType name
					  , '" must resolve to an object type at runtime for value '
					  , (self describeValue: aResult) , '.'
				  fields: aFieldCollection
				  path: aPath ].
	(schema isPossibleType: runtimeType for: anAbstractType) ifFalse: [
			^ self
				  fieldError: 'Runtime object type "' , runtimeType name
					  , '" is not a possible type for "' , anAbstractType name , '".'
				  fields: aFieldCollection
				  path: aPath ].
	^ self
		  completeObjectValue: runtimeType
		  fields: aFieldCollection
		  result: aResult
		  path: aPath
]

{ #category : 'private - completion' }
GQLExecutor >> completeLeafValue: aLeafType fields: aFieldCollection result: aResult path: aPath [
	| failure value |
	value := [ aLeafType serialize: aResult ]
		on: Error
		do: [ :e |
			failure := e.
			nil ].
	failure ifNotNil: [
		self fieldError: (self messageForException: failure) fields: aFieldCollection path: aPath ].
	^ value
]

{ #category : 'private - completion' }
GQLExecutor >> completeListItem: anItem type: anItemType fields: aFieldCollection path: aPath parentType: anObjectType fieldDefinition: aFieldDefinition [

	^ [
		  self
			  completeValue: anItemType
			  fields: aFieldCollection
			  result: anItem
			  path: aPath
			  parentType: anObjectType
			  fieldDefinition: aFieldDefinition ]
		  on: GQLFieldError
		  do: [ :e | anItemType recoverFromFieldError: e ]
]

{ #category : 'private - completion' }
GQLExecutor >> completeListValue: aListType fields: aFieldCollection result: aResult path: aPath parentType: anObjectType fieldDefinition: aFieldDefinition [
	"Complete each item (at most context maxListSize items); a single value is completed as a list of one item.
	A non-null item error propagates to the list"

	| items max |
	(self isListValue: aResult) ifFalse: [
			^ { (self
				   completeListItem: aResult
				   type: aListType ofType
				   fields: aFieldCollection
				   path: (aPath copyWith: 0)
				   parentType: anObjectType
				   fieldDefinition: aFieldDefinition) } ].
	max := context maxListSize.
	items := OrderedCollection new.
	aResult do: [ :each |
			items size >= max ifTrue: [ ^ items asArray ].
			items add: (self
					 completeListItem: each
					 type: aListType ofType
					 fields: aFieldCollection
					 path: (aPath copyWith: items size)
					 parentType: anObjectType
					 fieldDefinition: aFieldDefinition) ].
	^ items asArray
]

{ #category : 'private - completion' }
GQLExecutor >> completeNonNullValue: aNonNullType fields: aFieldCollection result: aResult path: aPath parentType: anObjectType fieldDefinition: aFieldDefinition [
	"Complete aResult as a value of the wrapped type; a null completed value is a field error"

	^ (self
		   completeValue: aNonNullType ofType
		   fields: aFieldCollection
		   result: aResult
		   path: aPath
		   parentType: anObjectType
		   fieldDefinition: aFieldDefinition) ifNil: [
			  self
				  fieldError:
					  'Cannot return null for non-nullable field '
					  , anObjectType name , '.' , aFieldDefinition name , '.'
				  fields: aFieldCollection
				  path: aPath ]
]

{ #category : 'private - completion' }
GQLExecutor >> completeObjectValue: anObjectType fields: aFieldCollection result: aResult path: aPath [
	"Execute the merged sub-selections of all the fields with the same response key on aResult"
	^ self
		executeFields: (self
			collectFields: anObjectType
			selectionSets: (aFieldCollection collect: [ :each | each selectionSet ])
			path: aPath)
		objectType: anObjectType
		source: aResult
		path: aPath
]

{ #category : 'private - completion' }
GQLExecutor >> completeUnsupportedValue: aType fields: aFieldCollection path: aPath [

	^ self
		  fieldError:
			  'Cannot complete value of unsupported type "' , aType printString
			  , '".'
		  fields: aFieldCollection
		  path: aPath
]

{ #category : 'private - completion' }
GQLExecutor >> completeValue: aType fields: aFieldCollection result: aResult path: aPath parentType: anObjectType fieldDefinition: aFieldDefinition [
	"Double dispatch on aType (non-null, list, leaf or object type)"

	^ aType
		  completeValue: aResult
		  fields: aFieldCollection
		  path: aPath
		  parentType: anObjectType
		  fieldDefinition: aFieldDefinition
		  executor: self
]

{ #category : 'private' }
GQLExecutor >> context [
	"The execution context of the request being executed (only set on the private copy performing the execution)"
	^ context
]

{ #category : 'private - errors' }
GQLExecutor >> describeValue: anObject [
	^ [ GQLScalarType describe: anObject ]
		on: Error
		do: [ :e | anObject printString ]
]

{ #category : 'private - fields collection' }
GQLExecutor >> directiveCondition: aDirective [
	"Answer the value of the if: argument of aDirective (nil if absent)"
	| node |
	node := aDirective arguments ifNotNil: [ :args | args at: 'if' ifAbsent: [ nil ] ].
	^ node ifNotNil: [ node valueWithVariables: context variables ]
]

{ #category : 'private - response' }
GQLExecutor >> errorResponseWithMessage: aString [
	^ self responseWithErrors: { GQLError message: aString }
]

{ #category : 'private - response' }
GQLExecutor >> errorsResponse [
	"Response for pre-execution errors: no data entry"
	^ self responseWithErrors: context errors
]

{ #category : 'executing' }
GQLExecutor >> execute: aQueryString [
	^ self execute: aQueryString operationName: nil variables: nil context: nil
]

{ #category : 'executing' }
GQLExecutor >> execute: aQueryString operationName: anOperationNameOrNil variables: aDictionaryOrNil context: anObject [
	"Execute a GraphQL request and answer an OrderedDictionary with 'data' and/or 'errors' (an Array of JSON-ready dictionaries).
	anObject is passed as third argument (context) to the field resolvers.
	The execution is performed on a copy of the receiver so that an executor can be shared."
	schema ifNil: [ ^ self errorResponseWithMessage: 'Internal error: no schema configured' ].
	^ [ self copy
			basicExecute: aQueryString
			operationName: anOperationNameOrNil
			variables: aDictionaryOrNil
			context: anObject ]
		on: Error
		do: [ :e | self errorResponseWithMessage: 'Internal error: ' , (self messageForException: e) ]
]

{ #category : 'executing' }
GQLExecutor >> execute: aQueryString variables: aDictionaryOrNil [
	^ self execute: aQueryString operationName: nil variables: aDictionaryOrNil context: nil
]

{ #category : 'private - executing' }
GQLExecutor >> executeField: aFieldCollection objectType: anObjectType source: aSource path: aPath into: aResultDictionary key: aResponseKey [
	| field fieldDefinition |
	field := aFieldCollection first.
	field name = '__typename' ifTrue: [ ^ aResultDictionary at: aResponseKey put: anObjectType name ].
	fieldDefinition := self fieldDefinitionNamed: field name in: anObjectType.
	fieldDefinition ifNil: [
		context addErrorOnce: (GQLError
			message: 'Cannot query field "' , field name asString , '" on type "' , anObjectType name , '".'
			path: aPath
			locations: (self locationsOf: aFieldCollection)).
		^ self ].
	aResultDictionary
		at: aResponseKey
		put: (self
			resolveField: fieldDefinition
			fields: aFieldCollection
			objectType: anObjectType
			source: aSource
			path: aPath)
]

{ #category : 'private - executing' }
GQLExecutor >> executeFields: aGroupedFields objectType: anObjectType source: aSource path: aPath [
	"aGroupedFields is an OrderedDictionary responseKey -> fields. Answer an OrderedDictionary responseKey -> value"
	| result |
	result := OrderedDictionary new.
	aGroupedFields keysAndValuesDo: [ :responseKey :fields |
		self
			executeField: fields
			objectType: anObjectType
			source: aSource
			path: (aPath copyWith: responseKey)
			into: result
			key: responseKey ].
	^ result
]

{ #category : 'private - executing' }
GQLExecutor >> executeOperation: anOperation [
	"Execute the root selection set serially; a non-null error propagated to the root makes data null"
	^ [ self
			executeSelectionSet: anOperation selectionSet
			objectType: schema queryType
			source: context rootValue
			path: #() ]
		on: GQLFieldError
		do: [ :e | nil ]
]

{ #category : 'private - executing' }
GQLExecutor >> executeSelectionSet: aSelectionSet objectType: anObjectType source: aSource path: aPath [
	^ self
		executeFields: (self collectFields: anObjectType selectionSets: { aSelectionSet } path: aPath)
		objectType: anObjectType
		source: aSource
		path: aPath
]

{ #category : 'private - executing' }
GQLExecutor >> fieldDefinitionNamed: aName in: anObjectType [
	"Answer the GQLFieldDefinition for aName in anObjectType, including meta fields (introspection) of the query type, or nil"

	^ (anObjectType fieldNamed: aName) ifNil: [
			  anObjectType == schema queryType ifTrue: [
				  schema metaFieldNamed: aName ] ]
]

{ #category : 'private - errors' }
GQLExecutor >> fieldError: aMessage fields: aFieldCollection path: aPath [
	"Record a field error and signal GQLFieldError to propagate null to the nearest nullable position"
	| error |
	error := GQLError message: aMessage path: aPath locations: (self locationsOf: aFieldCollection).
	context addError: error.
	^ GQLFieldError signalFor: error
]

{ #category : 'private - variables' }
GQLExecutor >> inputTypeOfVariable: aVariableDefinition ifInvalid: aBlock [
	"Answer the resolved input type of aVariableDefinition. Record an error and evaluate aBlock for unknown or non-input types"

	| type |
	type := [ schema resolveTypeRef: aVariableDefinition typeRef ]
		        on: Error
		        do: [ :e | nil ].
	type ifNil: [
			self
				addRequestError:
					'Unknown type "' , aVariableDefinition typeRef typeName asString
					, '".'
				nodes: { aVariableDefinition }.
			^ aBlock value ].
	type isInputType ifFalse: [
			self
				addRequestError:
					'Variable "$' , aVariableDefinition name asString
					, '" cannot be non-input type "' , type printString , '".'
				nodes: { aVariableDefinition }.
			^ aBlock value ].
	^ type
]

{ #category : 'private - fields collection' }
GQLExecutor >> isExcludedBy: aDirective [
	"Answer whether aDirective excludes its selection. Other directives, and if: arguments that are not
	exactly the excluding Boolean (e.g. non-Boolean literals), have no effect"

	^ (self class excludingConditions
		   at: aDirective name
		   ifAbsent: [ ^ false ]) == (self directiveCondition: aDirective)
]

{ #category : 'private - coercion' }
GQLExecutor >> isListValue: anObject [
	"Answer whether anObject should be handled as a list of items (Strings and Dictionaries are single values)"

	(anObject isNil or: [
		 anObject isString or: [ anObject isDictionary ] ]) ifTrue: [
		^ false ].
	^ anObject isCollection or: [
			  (anObject respondsTo: #do:) and: [
				  anObject respondsTo: #asOrderedCollection ] ]
]

{ #category : 'private - errors' }
GQLExecutor >> locationsOf: aNodeCollection [
	"Answer an Array of line/column Dictionaries for the nodes having a position, nil if none"

	^ (aNodeCollection
		   select: [ :each | each notNil and: [ each line notNil ] ]
		   thenCollect: [ :each | each location ]) asArray ifEmpty: [ nil ]
]

{ #category : 'accessing' }
GQLExecutor >> maxListSize [
	"Maximum number of items completed for a list field (nil means the GQLExecutionContext default)"
	^ maxListSize
]

{ #category : 'accessing' }
GQLExecutor >> maxListSize: anInteger [
	maxListSize := anInteger
]

{ #category : 'private - errors' }
GQLExecutor >> messageForException: anException [
	"Answer the message text of anException, or its class name when it has no usable text"

	| text |
	text := [ anException messageText ]
		        on: Error
		        do: [ :e | nil ].
	^ (text isString and: [ text notEmpty ])
		  ifTrue: [ text asString ]
		  ifFalse: [ anException class name asString ]
]

{ #category : 'private - executing' }
GQLExecutor >> missingArgument: anArgument named: aName fields: aFieldCollection path: aPath [
	"Answer the value of an argument given neither in the query nor by a default: nil, or a field error when it is required"

	anArgument type isNonNull ifTrue: [
			^ self
				  fieldError: 'Argument "' , aName , '" of required type "'
					  , anArgument type printString , '" was not provided.'
				  fields: aFieldCollection
				  path: aPath ].
	^ nil
]

{ #category : 'private - variables' }
GQLExecutor >> missingVariable: aVariableDefinition type: aType [
	"A variable neither provided nor having a default value is an error only when it is required"

	aType isNonNull ifFalse: [ ^ self ].
	self
		addRequestError: 'Variable "$' , aVariableDefinition name asString
			, '" of required type "' , aType printString
			, '" was not provided.'
		nodes: { aVariableDefinition }
]

{ #category : 'private - executing' }
GQLExecutor >> operationNamed: aString in: aDocument [
	"Answer the operation named aString, or nil after recording an error"

	^ (aDocument operationNamed: aString) ifNil: [
			  self
				  addRequestError: 'Unknown operation named "' , aString , '".'
				  nodes: #(  ).
			  nil ]
]

{ #category : 'private - executing' }
GQLExecutor >> resolve: aFieldDefinition source: aSource args: anArgsDictionary fields: aFieldCollection path: aPath [
	"Call the field resolver; any Error it signals becomes a field error"
	| failure value |
	value := [ aFieldDefinition resolve: aSource args: anArgsDictionary context: context userContext ]
		on: Error
		do: [ :e |
			failure := e.
			nil ].
	failure ifNotNil: [
		self fieldError: (self messageForException: failure) fields: aFieldCollection path: aPath ].
	^ value
]

{ #category : 'private - executing' }
GQLExecutor >> resolveField: aFieldDefinition fields: aFieldCollection objectType: anObjectType source: aSource path: aPath [
	"Answer the completed value of a field. Field errors make the value null when the field type is nullable, and are propagated otherwise"

	| type |
	type := aFieldDefinition type.
	^ [
		  | args value |
		  self
			  checkSelectionOf: aFieldDefinition
			  fields: aFieldCollection
			  path: aPath.
		  args := self
			          coerceArgumentsOf: aFieldDefinition
			          fields: aFieldCollection
			          path: aPath.
		  value := self
			           resolve: aFieldDefinition
			           source: aSource
			           args: args
			           fields: aFieldCollection
			           path: aPath.
		  self
			  completeValue: type
			  fields: aFieldCollection
			  result: value
			  path: aPath
			  parentType: anObjectType
			  fieldDefinition: aFieldDefinition ]
		  on: GQLFieldError
		  do: [ :e | type recoverFromFieldError: e ]
]

{ #category : 'private - response' }
GQLExecutor >> responseWithData: aDataDictionaryOrNil [
	| response |
	response := OrderedDictionary new.
	response at: 'data' put: aDataDictionaryOrNil.
	context hasErrors ifTrue: [
		response at: 'errors' put: (context errors asArray collect: [ :each | each asJsonDictionary ]) ].
	^ response
]

{ #category : 'private - response' }
GQLExecutor >> responseWithErrors: aGQLErrorCollection [
	^ OrderedDictionary new
		at: 'errors' put: (aGQLErrorCollection asArray collect: [ :each | each asJsonDictionary ]);
		yourself
]

{ #category : 'accessing' }
GQLExecutor >> rootValue [
	"The source object given to the resolvers of the root (query) fields"
	^ rootValue
]

{ #category : 'accessing' }
GQLExecutor >> rootValue: anObject [
	rootValue := anObject
]

{ #category : 'accessing' }
GQLExecutor >> schema [
	^ schema
]

{ #category : 'accessing' }
GQLExecutor >> schema: aGQLSchema [
	schema := aGQLSchema
]

{ #category : 'private - executing' }
GQLExecutor >> selectOperationNamed: anOperationNameOrNil in: aDocument [
	"Answer the operation to execute, or nil after recording an error"

	| operation |
	operation := (anOperationNameOrNil isNil or: [
		              anOperationNameOrNil isString and: [
			              anOperationNameOrNil isEmpty ] ])
		             ifTrue: [ self uniqueOperationIn: aDocument ]
		             ifFalse: [
		             self
			             operationNamed: anOperationNameOrNil asString
			             in: aDocument ].
	^ operation ifNotNil: [ self supportedOperation: operation ]
]

{ #category : 'private - fields collection' }
GQLExecutor >> shouldInclude: aSelection [
	"Apply the @skip(if:) and @include(if:) directives"

	^ (aSelection directives ifNil: [ ^ true ]) noneSatisfy: [ :directive |
		  self isExcludedBy: directive ]
]

{ #category : 'private - errors' }
GQLExecutor >> staticFieldError: aMessage fields: aFieldCollection path: aPath [
	"Like fieldError:fields:path: but the error is recorded only once per message and locations
	(static errors repeat for every item of a list)"
	| error |
	error := GQLError message: aMessage path: aPath locations: (self locationsOf: aFieldCollection).
	context addErrorOnce: error.
	^ GQLFieldError signalFor: error
]

{ #category : 'private - executing' }
GQLExecutor >> supportedOperation: anOperation [
	"Answer anOperation if it can be executed (only queries are supported), or nil after recording an error"

	anOperation isMutation ifTrue: [
			self
				addRequestError: 'Schema is not configured for mutations.'
				nodes: { anOperation }.
			^ nil ].
	anOperation isSubscription ifTrue: [
			self
				addRequestError: 'Schema is not configured for subscriptions.'
				nodes: { anOperation }.
			^ nil ].
	^ anOperation
]

{ #category : 'private - response' }
GQLExecutor >> syntaxErrorResponse: aSyntaxError [
	| message locations |
	message := aSyntaxError reason
		ifNil: [ self messageForException: aSyntaxError ]
		ifNotNil: [ aSyntaxError graphQLMessage ].
	locations := aSyntaxError line ifNotNil: [ :line |
		{ Dictionary new
			at: 'line' put: line;
			at: 'column' put: aSyntaxError column;
			yourself } ].
	^ self responseWithErrors: { GQLError message: message path: nil locations: locations }
]

{ #category : 'private - fields collection' }
GQLExecutor >> typeCondition: aTypeNameOrNil appliesTo: anObjectType [
	"A fragment applies when it has no type condition, when its type condition is the object type itself,
	or when it names an interface implemented by the object type"

	aTypeNameOrNil ifNil: [ ^ true ].
	aTypeNameOrNil asString = anObjectType name ifTrue: [ ^ true ].
	^ anObjectType implements: aTypeNameOrNil asString
]

{ #category : 'private - executing' }
GQLExecutor >> uniqueOperationIn: aDocument [
	"Answer the only operation of aDocument, or nil after recording an error"

	| operations |
	operations := aDocument operations.
	operations ifEmpty: [
			self addRequestError: 'Must provide an operation.' nodes: #(  ).
			^ nil ].
	operations size > 1 ifTrue: [
			self
				addRequestError:
				'Must provide operation name if query contains multiple operations.'
				nodes: #(  ).
			^ nil ].
	^ operations first
]

{ #category : 'private - fields collection' }
GQLExecutor >> unknownFragment: aFragmentSpread path: aPath [

	context addErrorOnce: (GQLError
			 message:
			 'Unknown fragment "' , aFragmentSpread name asString , '".'
			 path: aPath
			 locations: (self locationsOf: { aFragmentSpread }))
]
