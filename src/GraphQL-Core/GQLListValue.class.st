Class {
	#name : 'GQLListValue',
	#superclass : 'GQLValueNode',
	#instVars : [
		'values'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'instance creation' }
GQLListValue class >> values: aCollection [

	^ self new values: aCollection asOrderedCollection; yourself
]

{ #category : 'initialization' }
GQLListValue >> initialize [

	super initialize.
	values := OrderedCollection new
]

{ #category : 'testing' }
GQLListValue >> isConstant [

	^ values allSatisfy: [ :each | each isConstant ]
]

{ #category : 'printing' }
GQLListValue >> printGraphQLOn: aStream [

	aStream nextPut: $[.
	values do: [ :each | each printGraphQLOn: aStream ] separatedBy: [ aStream nextPutAll: ', ' ].
	aStream nextPut: $]
]

{ #category : 'evaluating' }
GQLListValue >> valueWithVariables: aDictionaryOrNil [

	^ (values collect: [ :each | each valueWithVariables: aDictionaryOrNil ]) asArray
]

{ #category : 'accessing' }
GQLListValue >> values [

	^ values
]

{ #category : 'accessing' }
GQLListValue >> values: anObject [

	values := anObject
]
