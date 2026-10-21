"
I wrap a primitive FM3 property of a Moose entity for GraphQL. My value is always a printable String (or nil); errors become '<error: ...>'.
"
Class {
	#name : 'MGProperty',
	#superclass : 'Object',
	#instVars : [
		'entity',
		'property',
		'registry'
	],
	#category : 'Moose-GraphQL-Model',
	#package : 'Moose-GraphQL',
	#tag : 'Model'
}

{ #category : 'instance creation' }
MGProperty class >> entity: anEntity property: anFM3Property registry: aRegistry [

	^ self new
		  setEntity: anEntity
		  property: anFM3Property
		  registry: aRegistry
]

{ #category : 'accessing' }
MGProperty >> entity [
	^ entity
]

{ #category : 'accessing' }
MGProperty >> id [
	"<entityId>/<propertyName>"
	^ MGSafe
		do: [ (registry idOfEntity: entity) , '/' , (self name ifNil: [ '' ]) ]
		default: nil
]

{ #category : 'accessing' }
MGProperty >> isDerived [
	^ MGSafe do: [ property isDerived == true ] default: false
]

{ #category : 'accessing' }
MGProperty >> name [
	^ MGSafe do: [ property name ifNotNil: [ :n | n asString ] ] default: nil
]

{ #category : 'accessing' }
MGProperty >> owner [
	"The entity owning this property"
	^ entity
]

{ #category : 'printing' }
MGProperty >> printOn: aStream [
	super printOn: aStream.
	aStream nextPut: $(; nextPutAll: (self id ifNil: [ '?' ]); nextPut: $)
]

{ #category : 'accessing' }
MGProperty >> property [
	"The wrapped FM3Property"
	^ property
]

{ #category : 'accessing' }
MGProperty >> registry [
	^ registry
]

{ #category : 'initialization' }
MGProperty >> setEntity: anEntity property: anFM3Property registry: aRegistry [

	entity := anEntity.
	property := anFM3Property.
	registry := aRegistry
]

{ #category : 'accessing' }
MGProperty >> type [
	"Name of the property type, or nil"
	^ MGSafe do: [ property type ifNotNil: [ :t | t name asString ] ] default: nil
]

{ #category : 'accessing' }
MGProperty >> value [
	"Printable value of the property, '<error: ...>' if reading it fails"
	^ [ MGSafe printValue: (entity mmGetProperty: property) ]
		on: Error
		do: [ :e | e return: (MGSafe errorString: e) ]
]
