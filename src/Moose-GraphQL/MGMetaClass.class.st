"
I wrap an FM3Class (a meta-class / entity type) in the context of one Moose model for GraphQL. My instances are the entities of that model whose metadescription is my FM3Class.
"
Class {
	#name : 'MGMetaClass',
	#superclass : 'Object',
	#instVars : [
		'model',
		'modelId',
		'fm3Class',
		'registry'
	],
	#category : 'Moose-GraphQL-Model',
	#package : 'Moose-GraphQL',
	#tag : 'Model'
}

{ #category : 'instance creation' }
MGMetaClass class >> model: aMooseModel modelId: aString fm3Class: anFM3Class registry: aRegistry [
	^ self new setModel: aMooseModel modelId: aString fm3Class: anFM3Class registry: aRegistry
]

{ #category : 'comparing' }
MGMetaClass >> = anObject [
	^ self class = anObject class and: [ fm3Class == anObject fm3Class and: [ model == anObject model ] ]
]

{ #category : 'accessing' }
MGMetaClass >> count [
	^ self instances size
]

{ #category : 'accessing' }
MGMetaClass >> fm3Class [
	^ fm3Class
]

{ #category : 'accessing' }
MGMetaClass >> fullName [
	^ MGSafe do: [ fm3Class fullName ifNotNil: [ :n | n asString ] ] default: nil
]

{ #category : 'comparing' }
MGMetaClass >> hash [
	^ fm3Class identityHash bitXor: model identityHash
]

{ #category : 'accessing' }
MGMetaClass >> id [
	"<modelId>:<FM3 fullName>"
	^ MGSafe do: [ modelId asString , ':' , self fullName asString ] default: nil
]

{ #category : 'accessing' }
MGMetaClass >> instances [
	"All entities of my model whose metadescription is my FM3Class (cached in the registry)"
	^ registry instancesOf: fm3Class model: model
]

{ #category : 'accessing' }
MGMetaClass >> instances: aTakeOrNil [
	^ MGSafe take: aTakeOrNil from: self instances
]

{ #category : 'accessing' }
MGMetaClass >> model [
	^ model
]

{ #category : 'accessing' }
MGMetaClass >> modelId [
	^ modelId
]

{ #category : 'accessing' }
MGMetaClass >> name [
	^ MGSafe do: [ fm3Class name ifNotNil: [ :n | n asString ] ] default: nil
]

{ #category : 'printing' }
MGMetaClass >> printOn: aStream [
	super printOn: aStream.
	aStream nextPut: $(; nextPutAll: (self id ifNil: [ '?' ]); nextPut: $)
]

{ #category : 'accessing' }
MGMetaClass >> registry [
	^ registry
]

{ #category : 'initialization' }
MGMetaClass >> setModel: aMooseModel modelId: aString fm3Class: anFM3Class registry: aRegistry [
	model := aMooseModel.
	modelId := aString.
	fm3Class := anFM3Class.
	registry := aRegistry
]

{ #category : 'accessing' }
MGMetaClass >> superclass [
	"The meta-class of my FM3 superclass in the same model, or nil"
	^ MGSafe
		do: [
			fm3Class superclass ifNotNil: [ :sup |
				(sup isKindOf: FM3Class) ifTrue: [ registry metaClassFor: sup model: model ] ifFalse: [ nil ] ] ]
		default: nil
]
