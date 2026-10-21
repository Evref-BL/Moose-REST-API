Class {
	#name : 'GQLVariableValue',
	#superclass : 'GQLValueNode',
	#instVars : [
		'name'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'instance creation' }
GQLVariableValue class >> named: aString [

	^ self new name: aString; yourself
]

{ #category : 'testing' }
GQLVariableValue >> isConstant [

	^ false
]

{ #category : 'testing' }
GQLVariableValue >> isDefinedIn: aDictionaryOrNil [
	"Answer true if the variable is provided (possibly with a null value) in aDictionaryOrNil"

	^ aDictionaryOrNil notNil and: [ aDictionaryOrNil includesKey: name ]
]

{ #category : 'testing' }
GQLVariableValue >> isVariable [

	^ true
]

{ #category : 'accessing' }
GQLVariableValue >> name [

	^ name
]

{ #category : 'accessing' }
GQLVariableValue >> name: anObject [

	name := anObject
]

{ #category : 'printing' }
GQLVariableValue >> printGraphQLOn: aStream [

	aStream nextPut: $$; nextPutAll: name
]

{ #category : 'evaluating' }
GQLVariableValue >> valueWithVariables: aDictionaryOrNil [

	aDictionaryOrNil ifNil: [ ^ nil ].
	^ aDictionaryOrNil at: name ifAbsent: [ nil ]
]
