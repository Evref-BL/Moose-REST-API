"
I add a ""@id"" property to all element.
If I have to export two times the same object, I replace the exported element by the value of id for this element
"
Class {
	#name : #MRJSONWriter,
	#superclass : #NeoJSONWriter,
	#instVars : [
		'currentID',
		'mapInstanceToID',
		'currentDepth',
		'maxDepth'
	],
	#category : #'Moose-REST-API'
}

{ #category : #'initialize-release' }
MRJSONWriter >> initialize [
	super initialize.
	currentID := 0.
	mapInstanceToID := Dictionary new.
	currentDepth := 0.
	maxDepth := 3
]

{ #category : #acccessing }
MRJSONWriter >> nextCurrentID [
	| tmp |
	tmp := currentID.
	currentID := currentID + 1.
	^ tmp
]

{ #category : #writing }
MRJSONWriter >> propertiesOfToExport: aMooseEntity [
	^ aMooseEntity allDeclaredProperties
		reject: [ :property | 
			property isDerived
				or: [ property hasOpposite
						or: [ (aMooseEntity propertyNamed: property name) isNil
								or: [ property type name = #Object or: [ (aMooseEntity propertyNamed: property name) isCollection and: [ (aMooseEntity propertyNamed: property name) isEmpty ] ] ] ] ] ]
]

{ #category : #writing }
MRJSONWriter >> relationsToExport: aMooseEntity [
	| col |
	col := OrderedCollection new.
	aMooseEntity allDeclaredProperties
		reject: [ :property | property hasOpposite not or: [ (aMooseEntity propertyNamed: property name) isNil ] ]
		thenDo: [ :property | 
			(aMooseEntity propertyNamed: property name) isCollection
				ifTrue: [ (aMooseEntity propertyNamed: property name) do: [ :value | col add: {aMooseEntity . property . value} ] ]
				ifFalse: [ col add: {aMooseEntity . property . (aMooseEntity propertyNamed: property name)} ] ].
	^ col
]

{ #category : #writing }
MRJSONWriter >> writeMooseEntity: aMooseEntity [
	self
		writeMapStreamingDo: [ :jsonMapWriter | 
			| id |
			id := self nextCurrentID.
			jsonMapWriter writeKey: '@id' value: id.
			mapInstanceToID at: aMooseEntity put: id.
			jsonMapWriter writeKey: 'fm.id' value: aMooseEntity mooseID.
			jsonMapWriter writeKey: 'fm.type' value: aMooseEntity mooseDescription fullName.
			(self propertiesOfToExport: aMooseEntity) do: [ :property | jsonMapWriter writeKey: property name value: (aMooseEntity propertyNamed: property name) ].
			currentDepth < maxDepth
				ifTrue: [ currentDepth := currentDepth + 1.
					(self relationsToExport: aMooseEntity) do: [ :relation | self writeMooseEntityRelation: relation inMap: jsonMapWriter ].
					currentDepth := currentDepth - 1 ] ]
]

{ #category : #writing }
MRJSONWriter >> writeMooseEntityRelation: aRelation inMap: jsonMapWriter [
	jsonMapWriter
		writeKey: aRelation second name
		value:
			(mapInstanceToID
				at: aRelation third
				ifAbsent: [ aRelation third ])
]
