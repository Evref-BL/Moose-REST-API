"
I hold the state of one GraphQL request execution performed by GQLExecutor:

- schema: the GQLSchema
- document: the parsed GQLDocument
- operation: the selected GQLOperationDefinition
- variables: Dictionary of coerced variable values (String keys)
- fragments: Dictionary fragment name -> GQLFragmentDefinition
- errors: OrderedCollection of GQLError collected during execution
- userContext: any object, passed as third argument to field resolvers
- rootValue: the source object given to root fields resolvers (nil by default)
- maxListSize: maximum number of items completed for a list field (default 10000)
"
Class {
	#name : 'GQLExecutionContext',
	#superclass : 'Object',
	#instVars : [
		'schema',
		'document',
		'operation',
		'variables',
		'fragments',
		'errors',
		'userContext',
		'rootValue',
		'maxListSize',
		'reportedErrorKeys'
	],
	#category : 'GraphQL-Core-Execution',
	#package : 'GraphQL-Core',
	#tag : 'Execution'
}

{ #category : 'defaults' }
GQLExecutionContext class >> defaultMaxListSize [
	^ 10000
]

{ #category : 'errors' }
GQLExecutionContext >> addError: aGQLError [
	"Record aGQLError and answer it"
	^ errors add: aGQLError
]

{ #category : 'errors' }
GQLExecutionContext >> addErrorOnce: aGQLError [
	"Record aGQLError unless an error with the same message and locations was already recorded through this method
	(avoids repeating static errors such as unknown fields for every item of a list). Answer aGQLError"
	| key |
	key := { aGQLError message. aGQLError locations }.
	(reportedErrorKeys includes: key) ifTrue: [ ^ aGQLError ].
	reportedErrorKeys add: key.
	^ self addError: aGQLError
]

{ #category : 'accessing' }
GQLExecutionContext >> document [
	^ document
]

{ #category : 'accessing' }
GQLExecutionContext >> document: anObject [
	document := anObject
]

{ #category : 'accessing' }
GQLExecutionContext >> errors [
	^ errors
]

{ #category : 'accessing' }
GQLExecutionContext >> errors: anObject [
	errors := anObject
]

{ #category : 'accessing' }
GQLExecutionContext >> fragments [
	^ fragments
]

{ #category : 'accessing' }
GQLExecutionContext >> fragments: anObject [
	fragments := anObject
]

{ #category : 'testing' }
GQLExecutionContext >> hasErrors [
	^ errors notEmpty
]

{ #category : 'initialization' }
GQLExecutionContext >> initialize [
	super initialize.
	variables := Dictionary new.
	fragments := Dictionary new.
	errors := OrderedCollection new.
	reportedErrorKeys := Set new.
	maxListSize := self class defaultMaxListSize
]

{ #category : 'accessing' }
GQLExecutionContext >> maxListSize [
	^ maxListSize
]

{ #category : 'accessing' }
GQLExecutionContext >> maxListSize: anObject [
	maxListSize := anObject
]

{ #category : 'accessing' }
GQLExecutionContext >> operation [
	^ operation
]

{ #category : 'accessing' }
GQLExecutionContext >> operation: anObject [
	operation := anObject
]

{ #category : 'accessing' }
GQLExecutionContext >> rootValue [
	^ rootValue
]

{ #category : 'accessing' }
GQLExecutionContext >> rootValue: anObject [
	rootValue := anObject
]

{ #category : 'accessing' }
GQLExecutionContext >> schema [
	^ schema
]

{ #category : 'accessing' }
GQLExecutionContext >> schema: anObject [
	schema := anObject
]

{ #category : 'accessing' }
GQLExecutionContext >> userContext [
	^ userContext
]

{ #category : 'accessing' }
GQLExecutionContext >> userContext: anObject [
	userContext := anObject
]

{ #category : 'accessing' }
GQLExecutionContext >> variables [
	^ variables
]

{ #category : 'accessing' }
GQLExecutionContext >> variables: anObject [
	variables := anObject
]
