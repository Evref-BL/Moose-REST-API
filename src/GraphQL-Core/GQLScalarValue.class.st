Class {
	#name : 'GQLScalarValue',
	#superclass : 'GQLValueNode',
	#instVars : [
		'value'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'instance creation' }
GQLScalarValue class >> value: anObject [

	^ self new value: anObject; yourself
]

{ #category : 'accessing' }
GQLScalarValue >> value [

	^ value
]

{ #category : 'accessing' }
GQLScalarValue >> value: anObject [

	value := anObject
]

{ #category : 'evaluating' }
GQLScalarValue >> valueWithVariables: aDictionaryOrNil [

	^ value
]
