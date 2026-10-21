"
Abstract GraphQL value literal. #valueWithVariables: answers the Pharo value (Integer, Float, String, Boolean, nil, enum name String, Array, Dictionary); #asGraphQLString answers GraphQL literal text.
"
Class {
	#name : 'GQLValueNode',
	#superclass : 'GQLNode',
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'printing' }
GQLValueNode >> asGraphQLString [

	^ String streamContents: [ :stream | self printGraphQLOn: stream ]
]

{ #category : 'evaluating' }
GQLValueNode >> constValue [
	"Answer the Pharo value of this node without variables"

	^ self valueWithVariables: nil
]

{ #category : 'testing' }
GQLValueNode >> isConstant [
	"Answer true if this value does not reference any variable"

	^ true
]

{ #category : 'testing' }
GQLValueNode >> isValue [

	^ true
]

{ #category : 'printing' }
GQLValueNode >> printGraphQL [

	^ self asGraphQLString
]

{ #category : 'printing' }
GQLValueNode >> printGraphQLOn: aStream [
	"Print the GraphQL literal form of this value on aStream"

	^ self subclassResponsibility
]

{ #category : 'printing' }
GQLValueNode >> printOn: aStream [

	aStream nextPutAll: self class name; nextPut: $(.
	self printGraphQLOn: aStream.
	aStream nextPut: $)
]

{ #category : 'evaluating' }
GQLValueNode >> valueWithVariables: aDictionaryOrNil [
	"Answer the Pharo value of this node, resolving variables in aDictionaryOrNil (missing variables answer nil)"

	^ self subclassResponsibility
]
