"
I am passed to the block of GQLSchemaBuilder>>object:fields: and let declare the fields of a GQLObjectType (field:type:..., see the field declaration protocol).
"
Class {
	#name : 'GQLObjectTypeBuilder',
	#superclass : 'Object',
	#instVars : [
		'objectType'
	],
	#category : 'GraphQL-Core-Schema',
	#package : 'GraphQL-Core',
	#tag : 'Schema'
}

{ #category : 'instance creation' }
GQLObjectTypeBuilder class >> on: aGQLObjectType [
	^ self new objectType: aGQLObjectType; yourself
]

{ #category : 'fields' }
GQLObjectTypeBuilder >> addField: aGQLFieldDefinition [
	^ objectType addField: aGQLFieldDefinition
]

{ #category : 'private' }
GQLObjectTypeBuilder >> argumentFrom: anObject [

	| spec |
	(anObject isKindOf: GQLArgument) ifTrue: [ ^ anObject ].
	anObject isAssociation ifFalse: [
		^ self error:
			  'Invalid argument declaration: ' , anObject printString ].
	spec := anObject value.
	(spec isString or: [
		 (spec isKindOf: GQLType) or: [ spec isKindOf: GQLTypeRef ] ])
		ifTrue: [ ^ GQLArgument name: anObject key type: spec ].
	(spec isCollection and: [ spec notEmpty ]) ifTrue: [
			^ spec size >= 2
				  ifTrue: [
					  GQLArgument
						  name: anObject key
						  type: spec first
						  default: spec second ]
				  ifFalse: [ GQLArgument name: anObject key type: spec first ] ].
	^ self error:
		  'Invalid type for argument "' , anObject key asString , '": '
		  , spec printString
]

{ #category : 'fields' }
GQLObjectTypeBuilder >> field: aName type: aTypeSpec [
	^ self field: aName type: aTypeSpec description: nil args: nil resolve: nil
]

{ #category : 'fields' }
GQLObjectTypeBuilder >> field: aName type: aTypeSpec args: anArgsCollection [
	^ self field: aName type: aTypeSpec description: nil args: anArgsCollection resolve: nil
]

{ #category : 'fields' }
GQLObjectTypeBuilder >> field: aName type: aTypeSpec args: anArgsCollection resolve: aBlock [
	^ self field: aName type: aTypeSpec description: nil args: anArgsCollection resolve: aBlock
]

{ #category : 'fields' }
GQLObjectTypeBuilder >> field: aName type: aTypeSpec description: aDescription [
	^ self field: aName type: aTypeSpec description: aDescription args: nil resolve: nil
]

{ #category : 'fields' }
GQLObjectTypeBuilder >> field: aName type: aTypeSpec description: aDescription args: anArgsCollection [
	^ self field: aName type: aTypeSpec description: aDescription args: anArgsCollection resolve: nil
]

{ #category : 'fields' }
GQLObjectTypeBuilder >> field: aName type: aTypeSpec description: aDescription args: anArgsCollection resolve: aBlock [
	"Declare a field and answer its GQLFieldDefinition.
	aTypeSpec: type String ('[Person!]!'), type ref AST or GQLType.
	anArgsCollection: nil or a collection whose elements are GQLArgument instances or Associations
	name -> typeString, name -> GQLType, or name -> { typeString. defaultValue }.
	aBlock: nil (default resolver) or [ :source :args :context | ... ]"
	| field |
	field := GQLFieldDefinition name: aName type: aTypeSpec.
	field description: aDescription.
	field resolver: aBlock.
	anArgsCollection ifNotNil: [
		anArgsCollection do: [ :each | field addArgument: (self argumentFrom: each) ] ].
	^ objectType addField: field
]

{ #category : 'fields' }
GQLObjectTypeBuilder >> field: aName type: aTypeSpec description: aDescription resolve: aBlock [
	^ self field: aName type: aTypeSpec description: aDescription args: nil resolve: aBlock
]

{ #category : 'fields' }
GQLObjectTypeBuilder >> field: aName type: aTypeSpec resolve: aBlock [
	^ self field: aName type: aTypeSpec description: nil args: nil resolve: aBlock
]

{ #category : 'accessing' }
GQLObjectTypeBuilder >> objectType [
	^ objectType
]

{ #category : 'accessing' }
GQLObjectTypeBuilder >> objectType: aGQLObjectType [
	objectType := aGQLObjectType
]
