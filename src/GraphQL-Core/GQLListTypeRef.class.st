Class {
	#name : 'GQLListTypeRef',
	#superclass : 'GQLTypeRef',
	#instVars : [
		'ofType'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'instance creation' }
GQLListTypeRef class >> of: aTypeRef [

	^ self new ofType: aTypeRef; yourself
]

{ #category : 'comparing' }
GQLListTypeRef >> = anObject [

	^ self class = anObject class and: [ ofType = anObject ofType ]
]

{ #category : 'comparing' }
GQLListTypeRef >> hash [

	^ ofType hash bitXor: 16r1F1F
]

{ #category : 'testing' }
GQLListTypeRef >> isList [

	^ true
]

{ #category : 'accessing' }
GQLListTypeRef >> namedType [

	^ ofType namedType
]

{ #category : 'accessing' }
GQLListTypeRef >> ofType [

	^ ofType
]

{ #category : 'accessing' }
GQLListTypeRef >> ofType: anObject [

	ofType := anObject
]

{ #category : 'printing' }
GQLListTypeRef >> printOn: aStream [

	aStream nextPut: $[; print: ofType; nextPut: $]
]
