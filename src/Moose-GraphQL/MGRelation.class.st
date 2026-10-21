"
I wrap a complex (entity-typed) FM3 property of a Moose entity for GraphQL. My values are computed lazily and are always an OrderedCollection of Moose entities (empty on error).
"
Class {
	#name : 'MGRelation',
	#superclass : 'Object',
	#instVars : [
		'entity',
		'property',
		'registry',
		'values'
	],
	#category : 'Moose-GraphQL-Model',
	#package : 'Moose-GraphQL',
	#tag : 'Model'
}

{ #category : 'instance creation' }
MGRelation class >> entity: anEntity property: anFM3Property registry: aRegistry [
	^ self new setEntity: anEntity property: anFM3Property registry: aRegistry
]

{ #category : 'accessing' }
MGRelation >> entity [
	^ entity
]

{ #category : 'accessing' }
MGRelation >> id [
	"<entityId>/<propertyName>"
	^ MGSafe
		do: [ (registry idOfEntity: entity) , '/' , (self name ifNil: [ '' ]) ]
		default: nil
]

{ #category : 'accessing' }
MGRelation >> isContainer [
	^ MGSafe do: [ property isContainer == true ] default: false
]

{ #category : 'accessing' }
MGRelation >> isDerived [
	^ MGSafe do: [ property isDerived == true ] default: false
]

{ #category : 'accessing' }
MGRelation >> isMultivalued [
	^ MGSafe do: [ property isMultivalued == true ] default: false
]

{ #category : 'accessing' }
MGRelation >> name [
	^ MGSafe do: [ property name ifNotNil: [ :n | n asString ] ] default: nil
]

{ #category : 'accessing' }
MGRelation >> owner [
	"The entity owning this property"
	^ entity
]

{ #category : 'printing' }
MGRelation >> printOn: aStream [
	super printOn: aStream.
	aStream nextPut: $(; nextPutAll: (self id ifNil: [ '?' ]); nextPut: $)
]

{ #category : 'accessing' }
MGRelation >> property [
	"The wrapped FM3Property"
	^ property
]

{ #category : 'accessing' }
MGRelation >> registry [
	^ registry
]

{ #category : 'initialization' }
MGRelation >> setEntity: anEntity property: anFM3Property registry: aRegistry [
	entity := anEntity.
	property := anFM3Property.
	registry := aRegistry
]

{ #category : 'accessing' }
MGRelation >> size [
	^ self values size
]

{ #category : 'accessing' }
MGRelation >> target [
	"First related entity, or nil"
	^ self values ifEmpty: [ nil ] ifNotEmpty: [ :v | v first ]
]

{ #category : 'accessing' }
MGRelation >> targets [
	^ self targets: nil
]

{ #category : 'accessing' }
MGRelation >> targets: aTakeOrNil [
	^ MGSafe take: aTakeOrNil from: self values
]

{ #category : 'accessing' }
MGRelation >> type [
	"Name of the property type, or nil"
	^ MGSafe do: [ property type ifNotNil: [ :t | t name asString ] ] default: nil
]

{ #category : 'accessing' }
MGRelation >> values [
	"Lazily computed OrderedCollection of the related entities (empty on error)"
	^ values ifNil: [
		values := [ MGSafe entitiesIn: (entity mmGetProperty: property) ]
			on: Error
			do: [ :e | e return: OrderedCollection new ] ]
]
