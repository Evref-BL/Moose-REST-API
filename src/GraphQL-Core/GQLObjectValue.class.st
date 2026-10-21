Class {
	#name : 'GQLObjectValue',
	#superclass : 'GQLValueNode',
	#instVars : [
		'fields'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'instance creation' }
GQLObjectValue class >> fields: anOrderedDictionary [

	^ self new fields: anOrderedDictionary; yourself
]

{ #category : 'accessing' }
GQLObjectValue >> fields [

	^ fields
]

{ #category : 'accessing' }
GQLObjectValue >> fields: anObject [

	fields := anObject
]

{ #category : 'initialization' }
GQLObjectValue >> initialize [

	super initialize.
	fields := OrderedDictionary new
]

{ #category : 'testing' }
GQLObjectValue >> isConstant [

	^ fields allSatisfy: [ :each | each isConstant ]
]

{ #category : 'printing' }
GQLObjectValue >> printGraphQLOn: aStream [

	aStream nextPut: ${.
	fields associations
		do: [ :each |
			aStream nextPutAll: each key; nextPutAll: ': '.
			each value printGraphQLOn: aStream ]
		separatedBy: [ aStream nextPutAll: ', ' ].
	aStream nextPut: $}
]

{ #category : 'evaluating' }
GQLObjectValue >> valueWithVariables: aDictionaryOrNil [

	| result |
	result := Dictionary new.
	fields keysAndValuesDo: [ :key :node | result at: key put: (node valueWithVariables: aDictionaryOrNil) ].
	^ result
]
