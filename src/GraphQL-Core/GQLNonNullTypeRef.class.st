Class {
	#name : 'GQLNonNullTypeRef',
	#superclass : 'GQLTypeRef',
	#instVars : [
		'ofType'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'instance creation' }
GQLNonNullTypeRef class >> of: aTypeRef [

	^ self new ofType: aTypeRef; yourself
]

{ #category : 'comparing' }
GQLNonNullTypeRef >> = anObject [

	^ self class = anObject class and: [ ofType = anObject ofType ]
]

{ #category : 'comparing' }
GQLNonNullTypeRef >> hash [

	^ ofType hash bitXor: 16r2E2E
]

{ #category : 'testing' }
GQLNonNullTypeRef >> isNonNull [

	^ true
]

{ #category : 'accessing' }
GQLNonNullTypeRef >> namedType [

	^ ofType namedType
]

{ #category : 'accessing' }
GQLNonNullTypeRef >> nullableType [

	^ ofType
]

{ #category : 'accessing' }
GQLNonNullTypeRef >> ofType [

	^ ofType
]

{ #category : 'accessing' }
GQLNonNullTypeRef >> ofType: anObject [

	ofType := anObject
]

{ #category : 'printing' }
GQLNonNullTypeRef >> printOn: aStream [

	aStream print: ofType; nextPut: $!
]

{ #category : 'resolving' }
GQLNonNullTypeRef >> resolveIn: aSchema [

	^ GQLNonNullType of: (aSchema resolveTypeRef: ofType)
]
