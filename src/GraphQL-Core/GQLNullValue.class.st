Class {
	#name : 'GQLNullValue',
	#superclass : 'GQLValueNode',
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'testing' }
GQLNullValue >> isNull [

	^ true
]

{ #category : 'printing' }
GQLNullValue >> printGraphQLOn: aStream [

	aStream nextPutAll: 'null'
]

{ #category : 'evaluating' }
GQLNullValue >> valueWithVariables: aDictionaryOrNil [

	^ nil
]
