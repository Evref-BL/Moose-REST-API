Class {
	#name : 'GQLSelection',
	#superclass : 'GQLNode',
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'execution' }
GQLSelection >> collectFieldsFor: anObjectType visited: aVisitedSet into: aGroupedDictionary path: aPath executor: anExecutor [
	"Double dispatch from GQLExecutor: add the fields selected by the receiver to aGroupedDictionary (responseKey -> fields)"

	^ self subclassResponsibility
]

{ #category : 'testing' }
GQLSelection >> isSelection [

	^ true
]
