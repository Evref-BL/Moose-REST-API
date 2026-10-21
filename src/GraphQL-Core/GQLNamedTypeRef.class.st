Class {
	#name : 'GQLNamedTypeRef',
	#superclass : 'GQLTypeRef',
	#instVars : [
		'name'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'instance creation' }
GQLNamedTypeRef class >> named: aString [

	^ self new name: aString; yourself
]

{ #category : 'comparing' }
GQLNamedTypeRef >> = anObject [

	^ self class = anObject class and: [ name = anObject name ]
]

{ #category : 'comparing' }
GQLNamedTypeRef >> hash [

	^ name hash
]

{ #category : 'testing' }
GQLNamedTypeRef >> isNamed [

	^ true
]

{ #category : 'accessing' }
GQLNamedTypeRef >> name [

	^ name
]

{ #category : 'accessing' }
GQLNamedTypeRef >> name: anObject [

	name := anObject
]

{ #category : 'accessing' }
GQLNamedTypeRef >> namedType [

	^ self
]

{ #category : 'printing' }
GQLNamedTypeRef >> printOn: aStream [

	aStream nextPutAll: name asString
]
