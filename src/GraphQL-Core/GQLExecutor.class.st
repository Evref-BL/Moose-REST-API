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
	"Leaf fields must not have sub-selections, object fields must have one"
	| namedType fieldName |
	namedType := aFieldDefinition type namedType.
	fieldName := aFieldCollection first name asString.
	(namedType isLeaf and: [ aFieldCollection anySatisfy: [ :each | each selectionSet notNil ] ]) ifTrue: [
		^ self
			staticFieldError: 'Field "' , fieldName , '" must not have a selection since type "' , aFieldDefinition type printString , '" has no subfields.'
			fields: aFieldCollection
			path: aPath ].
	(namedType isObject and: [ aFieldCollection allSatisfy: [ :each | each selectionSet isNil ] ]) ifTrue: [
		^ self
			staticFieldError: 'Field "' , fieldName , '" of type "' , aFieldDefinition type printString , '" must have a selection of subfields.'
			fields: aFieldCollection
			path: aPath ]
]

{ #category : 'private - executing' }
GQLExecutor >> coerceArgumentsOf: aFieldDefinition fields: aFieldCollection path: aPath [
	"Answer a Dictionary argument name (String) -> coerced value for all the arguments defined by aFieldDefinition.
	Arguments given in the query but not defined are ignored"
	| field args |
	field := aFieldCollection first.
	args := Dictionary new.
	aFieldDefinition arguments keysAndValuesDo: [ :argName :argument |
		| node hasValue value failure |
		hasValue := false.
		node := field arguments ifNotNil: [ :nodes | nodes at: argName ifAbsent: [ nil ] ].
		node ifNotNil: [
			(node isVariable not or: [ node isDefinedIn: context variables ]) ifTrue: [
				hasValue := true.
				value := node valueWithVariables: context variables ] ].
		(hasValue not and: [ argument hasDefault ]) ifTrue: [
			hasValue := true.
			value := argument defaultValue ].
		(argument type isNonNull and: [ value isNil ]) ifTrue: [
			self
				fieldError: (hasValue
					ifTrue: [ 'Argument "' , argName , '" of non-null type "' , argument type printString , '" must not be null.' ]
					ifFalse: [ 'Argument "' , argName , '" of required type "' , argument type printString , '" was not provided.' ])
				fields: aFieldCollection
				path: aPath ].
		(hasValue and: [ node notNil ]) ifTrue: [
			value := [ self coerceInputValue: value type: argument type ]
				on: GQLCoercionError
				do: [ :e |
					failure := e.
					nil ].
			failure ifNotNil: [
				self
					fieldError: 'Argument "' , argName , '" has invalid value ' , (self describeValue: (node valueWithVariables: context variables)) , '; ' , (self messageForException: failure)
					fields: aFieldCollection
					path: aPath ] ].
		args at: argName put: value ].
	^ args
]

{ #category : 'private - coercion' }
GQLExecutor >> coerceInputValue: aValue type: aType [
	"Coerce an input value (variable or argument) against aType. Signal GQLCoercionError on invalid values"
	aType isNonNull ifTrue: [
		aValue ifNil: [
			^ GQLCoercionError signal: 'Expected non-nullable type "' , aType printString , '" not to be null.' ].
		^ self coerceInputValue: aValue type: aType ofType ].
	aValue ifNil: [ ^ nil ].
	aType isList ifTrue: [
		(self isListValue: aValue) ifFalse: [ ^ Array with: (self coerceInputValue: aValue type: aType ofType) ].
		^ Array streamContents: [ :stream |
			aValue do: [ :each | stream nextPut: (self coerceInputValue: each type: aType ofType) ] ] ].
	aType isLeaf ifTrue: [ ^ aType coerce: aValue ].
	^ GQLCoercionError signal: 'Type "' , aType printString , '" is not an input type.'
]

{ #category : 'private - variables' }
GQLExecutor >> coerceVariable: aVariableDefinition from: aProvidedDictionary into: aResultDictionary [
	| name type value coerced hasValue failure |
	name := aVariableDefinition name asString.
	type := [ schema resolveTypeRef: aVariableDefinition typeRef ]
		on: Error
		do: [ :e | nil ].
	type ifNil: [
		^ self
			addRequestError: 'Unknown type "' , aVariableDefinition typeRef typeName asString , '".'
			nodes: { aVariableDefinition } ].
	type isInputType ifFalse: [
		^ self
			addRequestError: 'Variable "$' , name , '" cannot be non-input type "' , type printString , '".'
			nodes: { aVariableDefinition } ].
	hasValue := false.
	(aProvidedDictionary includesKey: name)
		ifTrue: [
			hasValue := true.
			value := aProvidedDictionary at: name ]
		ifFalse: [
			aVariableDefinition defaultValue ifNotNil: [ :node |
				hasValue := true.
				value := node valueWithVariables: nil ] ].
	(type isNonNull and: [ value isNil ]) ifTrue: [
		^ self
			addRequestError: (hasValue
				ifTrue: [ 'Variable "$' , name , '" of non-null type "' , type printString , '" must not be null.' ]
				ifFalse: [ 'Variable "$' , name , '" of required type "' , type printString , '" was not provided.' ])
			nodes: { aVariableDefinition } ].
	hasValue ifFalse: [ ^ self ].
	coerced := [ self coerceInputValue: value type: type ]
		on: GQLCoercionError
		do: [ :e |
			failure := e.
			nil ].
	failure ifNotNil: [
		^ self
			addRequestError: 'Variable "$' , name , '" got invalid value ' , (self describeValue: value) , '; ' , (self messageForException: failure)
			nodes: { aVariableDefinition } ].
	aResultDictionary at: name put: coerced
]

{ #category : 'private - variables' }
GQLExecutor >> coerceVariableValues: aDictionaryOrNil [
	"Answer a Dictionary of coerced variable values for the operation variable definitions; errors are recorded in the context"
	| provided result |
	provided := Dictionary new.
	(aDictionaryOrNil notNil and: [ aDictionaryOrNil isDictionary ]) ifTrue: [
		aDictionaryOrNil keysAndValuesDo: [ :key :value | provided at: key asString put: value ] ].
	result := Dictionary new.
	context operation variableDefinitions do: [ :definition |
		self coerceVariable: definition from: provided into: result ].
	^ result
]

{ #category : 'private - fields collection' }
GQLExecutor >> collectFields: anObjectType selectionSet: aSelectionSet visited: aVisitedSet into: aGroupedDictionary path: aPath [
	aSelectionSet selections do: [ :selection |
		(self shouldInclude: selection) ifTrue: [
			selection isField ifTrue: [
				(aGroupedDictionary at: selection responseKey ifAbsentPut: [ OrderedCollection new ]) add: selection ].
			selection isInlineFragment ifTrue: [
				(self typeCondition: selection typeCondition appliesTo: anObjectType) ifTrue: [
					self
						collectFields: anObjectType
						selectionSet: selection selectionSet
						visited: aVisitedSet
						into: aGroupedDictionary
						path: aPath ] ].
			selection isFragmentSpread ifTrue: [
				self
					collectFragmentSpread: selection
					objectType: anObjectType
					visited: aVisitedSet
					into: aGroupedDictionary
					path: aPath ] ] ]
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
	fragment := context fragments at: aFragmentSpread name ifAbsent: [ nil ].
	fragment ifNil: [
		context addErrorOnce: (GQLError
			message: 'Unknown fragment "' , aFragmentSpread name asString , '".'
			path: aPath
			locations: (self locationsOf: { aFragmentSpread })).
		^ self ].
	(self typeCondition: fragment typeCondition appliesTo: anObjectType) ifFalse: [ ^ self ].
	self
		collectFields: anObjectType
		selectionSet: fragment selectionSet
		visited: aVisitedSet
		into: aGroupedDictionary
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
	^ [ self
			completeValue: anItemType
			fields: aFieldCollection
			result: anItem
			path: aPath
			parentType: anObjectType
			fieldDefinition: aFieldDefinition ]
		on: GQLFieldError
		do: [ :e |
			anItemType isNonNull
				ifTrue: [ e pass ]
				ifFalse: [ nil ] ]
]

{ #category : 'private - completion' }
GQLExecutor >> completeListValue: aListType fields: aFieldCollection result: aResult path: aPath parentType: anObjectType fieldDefinition: aFieldDefinition [
	"Complete each item (at most context maxListSize items). A non-null item error propagates to the list"
	| itemType items index max |
	itemType := aListType ofType.
	max := context maxListSize.
	items := OrderedCollection new.
	index := 0.
	(self isListValue: aResult)
		ifFalse: [
			items add: (self
				completeListItem: aResult
				type: itemType
				fields: aFieldCollection
				path: (aPath copyWith: 0)
				parentType: anObjectType
				fieldDefinition: aFieldDefinition) ]
		ifTrue: [
			aResult do: [ :each |
				index >= max ifTrue: [ ^ items asArray ].
				items add: (self
					completeListItem: each
					type: itemType
					fields: aFieldCollection
					path: (aPath copyWith: index)
					parentType: anObjectType
					fieldDefinition: aFieldDefinition).
				index := index + 1 ] ].
	^ items asArray
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
GQLExecutor >> completeValue: aType fields: aFieldCollection result: aResult path: aPath parentType: anObjectType fieldDefinition: aFieldDefinition [
	| completed |
	aType isNonNull ifTrue: [
		completed := self
			completeValue: aType ofType
			fields: aFieldCollection
			result: aResult
			path: aPath
			parentType: anObjectType
			fieldDefinition: aFieldDefinition.
		completed ifNil: [
			self
				fieldError: 'Cannot return null for non-nullable field ' , anObjectType name , '.' , aFieldDefinition name , '.'
				fields: aFieldCollection
				path: aPath ].
		^ completed ].
	aResult ifNil: [ ^ nil ].
	aType isList ifTrue: [
		^ self
			completeListValue: aType
			fields: aFieldCollection
			result: aResult
			path: aPath
			parentType: anObjectType
			fieldDefinition: aFieldDefinition ].
	aType isLeaf ifTrue: [ ^ self completeLeafValue: aType fields: aFieldCollection result: aResult path: aPath ].
	aType isObject ifTrue: [ ^ self completeObjectValue: aType fields: aFieldCollection result: aResult path: aPath ].
	^ self
		fieldError: 'Cannot complete value of unsupported type "' , aType printString , '".'
		fields: aFieldCollection
		path: aPath
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
	(anObjectType fieldNamed: aName) ifNotNil: [ :definition | ^ definition ].
	anObjectType == schema queryType ifTrue: [ ^ schema metaFieldNamed: aName ].
	^ nil
]

{ #category : 'private - errors' }
GQLExecutor >> fieldError: aMessage fields: aFieldCollection path: aPath [
	"Record a field error and signal GQLFieldError to propagate null to the nearest nullable position"
	| error |
	error := GQLError message: aMessage path: aPath locations: (self locationsOf: aFieldCollection).
	context addError: error.
	^ GQLFieldError signalFor: error
]

{ #category : 'private - coercion' }
GQLExecutor >> isListValue: anObject [
	"Answer whether anObject should be handled as a list of items (Strings and Dictionaries are single values)"
	anObject ifNil: [ ^ false ].
	anObject isString ifTrue: [ ^ false ].
	anObject isDictionary ifTrue: [ ^ false ].
	anObject isCollection ifTrue: [ ^ true ].
	^ (anObject respondsTo: #do:) and: [ anObject respondsTo: #asOrderedCollection ]
]

{ #category : 'private - errors' }
GQLExecutor >> locationsOf: aNodeCollection [
	"Answer an Array of line/column Dictionaries for the nodes having a position, nil if none"
	| locations |
	locations := (aNodeCollection select: [ :each | each notNil and: [ each line notNil ] ])
		collect: [ :each | each location ].
	^ locations isEmpty
		ifTrue: [ nil ]
		ifFalse: [ locations asArray ]
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
	| text |
	text := [ anException messageText ]
		on: Error
		do: [ :e | nil ].
	(text isNil or: [ text isString not or: [ text isEmpty ] ]) ifTrue: [ ^ anException class name asString ].
	^ text asString
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
	^ [ | args value |
		self checkSelectionOf: aFieldDefinition fields: aFieldCollection path: aPath.
		args := self coerceArgumentsOf: aFieldDefinition fields: aFieldCollection path: aPath.
		value := self resolve: aFieldDefinition source: aSource args: args fields: aFieldCollection path: aPath.
		self
			completeValue: type
			fields: aFieldCollection
			result: value
			path: aPath
			parentType: anObjectType
			fieldDefinition: aFieldDefinition ]
		on: GQLFieldError
		do: [ :e |
			type isNonNull
				ifTrue: [ e pass ]
				ifFalse: [ nil ] ]
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
	| operations operation |
	operations := aDocument operations.
	(anOperationNameOrNil isNil or: [ anOperationNameOrNil isString and: [ anOperationNameOrNil isEmpty ] ])
		ifTrue: [
			operations isEmpty ifTrue: [
				self addRequestError: 'Must provide an operation.' nodes: #().
				^ nil ].
			operations size > 1 ifTrue: [
				self addRequestError: 'Must provide operation name if query contains multiple operations.' nodes: #().
				^ nil ].
			operation := operations first ]
		ifFalse: [
			operation := aDocument operationNamed: anOperationNameOrNil asString.
			operation ifNil: [
				self addRequestError: 'Unknown operation named "' , anOperationNameOrNil asString , '".' nodes: #().
				^ nil ] ].
	operation isMutation ifTrue: [
		self addRequestError: 'Schema is not configured for mutations.' nodes: { operation }.
		^ nil ].
	operation isSubscription ifTrue: [
		self addRequestError: 'Schema is not configured for subscriptions.' nodes: { operation }.
		^ nil ].
	^ operation
]

{ #category : 'private - fields collection' }
GQLExecutor >> shouldInclude: aSelection [
	"Apply the @skip(if:) and @include(if:) directives"
	aSelection directives ifNil: [ ^ true ].
	aSelection directives do: [ :directive |
		(directive name = 'skip' and: [ (self directiveCondition: directive) == true ]) ifTrue: [ ^ false ].
		(directive name = 'include' and: [ (self directiveCondition: directive) == false ]) ifTrue: [ ^ false ] ].
	^ true
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
	^ aTypeNameOrNil isNil or: [ aTypeNameOrNil asString = anObjectType name ]
]
