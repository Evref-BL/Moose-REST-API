"
I am a GraphQL object type; fields is an OrderedDictionary name -> GQLFieldDefinition.
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
