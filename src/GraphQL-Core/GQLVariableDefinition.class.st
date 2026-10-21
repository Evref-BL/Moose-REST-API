Class {
	#name : 'GQLVariableDefinition',
	#superclass : 'GQLNode',
	#instVars : [
		'name',
		'typeRef',
		'defaultValue',
		'directives'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'accessing' }
GQLVariableDefinition >> defaultValue [

	^ defaultValue
]

{ #category : 'accessing' }
GQLVariableDefinition >> defaultValue: anObject [

	defaultValue := anObject
]

{ #category : 'accessing' }
GQLVariableDefinition >> directives [

	^ directives
]

{ #category : 'accessing' }
GQLVariableDefinition >> directives: anObject [

	directives := anObject
]

{ #category : 'initialization' }
GQLVariableDefinition >> initialize [

	super initialize.
	directives := OrderedCollection new
]

{ #category : 'accessing' }
GQLVariableDefinition >> name [

	^ name
]

{ #category : 'accessing' }
GQLVariableDefinition >> name: anObject [

	name := anObject
]

{ #category : 'printing' }
GQLVariableDefinition >> printOn: aStream [

	aStream nextPutAll: 'GQLVariableDefinition($'; nextPutAll: name asString; nextPutAll: ': '; print: typeRef.
	defaultValue ifNotNil: [ aStream nextPutAll: ' = '; nextPutAll: defaultValue asGraphQLString ].
	aStream nextPut: $)
]

{ #category : 'accessing' }
GQLVariableDefinition >> typeRef [

	^ typeRef
]

{ #category : 'accessing' }
GQLVariableDefinition >> typeRef: anObject [

	typeRef := anObject
]
