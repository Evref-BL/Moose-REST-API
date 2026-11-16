"
I am a GraphQL object type: a concrete composite type (see GQLCompositeType). My fields are an OrderedDictionary name -> GQLFieldDefinition.

I may implement interfaces (GQLInterfaceType): I then must provide every field they declare with compatible types and arguments, which the schema checks (GQLSchema>>validateInterfacesOf:). I am the only kind of type that can be the runtime type of a value of an abstract (interface) type.
"
Class {
	#name : 'GQLObjectType',
	#superclass : 'GQLCompositeType',
	#category : 'GraphQL-Core-Schema',
	#package : 'GraphQL-Core',
	#tag : 'Schema'
}

{ #category : 'execution' }
GQLObjectType >> completePresentValue: aResult fields: aFieldCollection path: aPath parentType: anObjectType fieldDefinition: aFieldDefinition executor: anExecutor [

	^ anExecutor
		  completeObjectValue: self
		  fields: aFieldCollection
		  result: aResult
		  path: aPath
]

{ #category : 'testing' }
GQLObjectType >> isObject [
	^ true
]

{ #category : 'accessing' }
GQLObjectType >> kind [
	^ 'OBJECT'
]
