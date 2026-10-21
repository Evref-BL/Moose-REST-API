Class {
	#name : 'GQLOperationDefinition',
	#superclass : 'GQLDefinition',
	#instVars : [
		'operation',
		'name',
		'variableDefinitions',
		'directives',
		'selectionSet'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'accessing' }
GQLOperationDefinition >> directives [

	^ directives
]

{ #category : 'accessing' }
GQLOperationDefinition >> directives: anObject [

	directives := anObject
]

{ #category : 'initialization' }
GQLOperationDefinition >> initialize [

	super initialize.
	operation := #query.
	variableDefinitions := OrderedCollection new.
	directives := OrderedCollection new
]

{ #category : 'testing' }
GQLOperationDefinition >> isMutation [

	^ operation = #mutation
]

{ #category : 'testing' }
GQLOperationDefinition >> isOperationDefinition [

	^ true
]

{ #category : 'testing' }
GQLOperationDefinition >> isQuery [

	^ operation = #query
]

{ #category : 'testing' }
GQLOperationDefinition >> isSubscription [

	^ operation = #subscription
]

{ #category : 'accessing' }
GQLOperationDefinition >> name [

	^ name
]

{ #category : 'accessing' }
GQLOperationDefinition >> name: anObject [

	name := anObject
]

{ #category : 'accessing' }
GQLOperationDefinition >> operation [

	^ operation
]

{ #category : 'accessing' }
GQLOperationDefinition >> operation: anObject [

	operation := anObject
]

{ #category : 'printing' }
GQLOperationDefinition >> printOn: aStream [

	aStream nextPutAll: 'GQLOperationDefinition('; nextPutAll: operation asString.
	name ifNotNil: [ aStream space; nextPutAll: name ].
	aStream nextPut: $)
]

{ #category : 'accessing' }
GQLOperationDefinition >> selectionSet [

	^ selectionSet
]

{ #category : 'accessing' }
GQLOperationDefinition >> selectionSet: anObject [

	selectionSet := anObject
]

{ #category : 'accessing' }
GQLOperationDefinition >> variableDefinitions [

	^ variableDefinitions
]

{ #category : 'accessing' }
GQLOperationDefinition >> variableDefinitions: anObject [

	variableDefinitions := anObject
]
