"
I am a GraphQL interface type: an abstract composite type declaring fields that the object types (or interfaces) implementing me must provide.

At execution time, the concrete object type of a value of my type is determined by my resolveTypeBlock if set, otherwise by the schema typeResolver (see GQLSchema>>runtimeTypeOf:abstractType:context:). The block is evaluated with cull: value cull: context cull: abstractType and answers the name of an object type (or the object type itself).
"
Class {
	#name : 'GQLInterfaceType',
	#superclass : 'GQLCompositeType',
	#instVars : [
		'resolveTypeBlock'
	],
	#category : 'GraphQL-Core-Schema',
	#package : 'GraphQL-Core',
	#tag : 'Schema'
}

{ #category : 'executing' }
GQLInterfaceType >> completePresentValue: aResult fields: aFieldCollection path: aPath parentType: anObjectType fieldDefinition: aFieldDefinition executor: anExecutor [
	"Determine the concrete object type of aResult at runtime and complete it as an object of that type"

	^ anExecutor
		  completeAbstractValue: self
		  fields: aFieldCollection
		  result: aResult
		  path: aPath
]

{ #category : 'testing' }
GQLInterfaceType >> isAbstract [

	^ true
]

{ #category : 'testing' }
GQLInterfaceType >> isInterface [

	^ true
]

{ #category : 'accessing' }
GQLInterfaceType >> kind [

	^ 'INTERFACE'
]

{ #category : 'accessing' }
GQLInterfaceType >> resolveTypeBlock [
	"Block answering the concrete object type (or its name) of a value of the receiver type, nil to use the schema typeResolver"

	^ resolveTypeBlock
]

{ #category : 'accessing' }
GQLInterfaceType >> resolveTypeBlock: aBlock [
	"aBlock is evaluated with cull: value cull: context cull: the receiver and answers the name of the concrete object type (or the type itself)"

	resolveTypeBlock := aBlock
]
