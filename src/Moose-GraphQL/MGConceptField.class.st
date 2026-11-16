"
I am the specification of a field of a concept object type in a per-model GraphQL schema (see MGModelSchemaBuilder>>#fieldSpecsOf:), computed before the types are defined.

- name: the GraphQL field name
- property: the FM3 property exposed by the field
- kind: #scalar or #relation
- scalarName: the scalar type name of a scalar field (nil for relations)
- target: the MGConcept typing a relation field, nil meaning the MooseEntity interface
- multivalued: whether the field answers a list

Scalar fields are typed S, or [S] when multivalued; relation fields are typed T, or [T!]! with a take argument when multivalued.
#isCompatibleImplementationOf: tells whether I may implement a field of an interface.
"
Class {
	#name : 'MGConceptField',
	#superclass : 'Object',
	#instVars : [
		'name',
		'property',
		'kind',
		'scalarName',
		'target',
		'multivalued'
	],
	#category : 'Moose-GraphQL-Schema',
	#package : 'Moose-GraphQL',
	#tag : 'Schema'
}

{ #category : 'instance creation' }
MGConceptField class >> relationNamed: aName property: anFM3Property target: aConceptOrNil multivalued: aBoolean [
	"A relation field aName exposing anFM3Property, typed with aConceptOrNil (nil meaning the MooseEntity interface)"

	^ self new
		  setName: aName
		  property: anFM3Property
		  kind: #relation
		  scalarName: nil
		  target: aConceptOrNil
		  multivalued: aBoolean
]

{ #category : 'instance creation' }
MGConceptField class >> scalarNamed: aName property: anFM3Property scalarName: aScalarName multivalued: aBoolean [
	"A scalar field aName exposing anFM3Property with the scalar aScalarName"

	^ self new
		  setName: aName
		  property: anFM3Property
		  kind: #scalar
		  scalarName: aScalarName
		  target: nil
		  multivalued: aBoolean
]

{ #category : 'testing' }
MGConceptField >> hasTakeArgument [
	"Multivalued relations accept a take argument bounding the number of answered entities"

	^ self isRelation and: [ self multivalued ]
]

{ #category : 'testing' }
MGConceptField >> isCompatibleImplementationOf: anInterfaceField [
	"Whether I may implement anInterfaceField: same name, kind and multiplicity, same scalar, or a target conforming to the interface field target (any when it is nil)"

	(name = anInterfaceField name and: [
		 kind = anInterfaceField kind and: [
			 self multivalued = anInterfaceField multivalued ] ]) ifFalse: [ ^ false ].
	self isScalar ifTrue: [ ^ scalarName = anInterfaceField scalarName ].
	^ anInterfaceField target isNil or: [
		  target == anInterfaceField target or: [
			  target notNil and: [
				  target interfaces includes: anInterfaceField target ] ] ]
]

{ #category : 'testing' }
MGConceptField >> isRelation [
	^ kind = #relation
]

{ #category : 'testing' }
MGConceptField >> isScalar [
	^ kind = #scalar
]

{ #category : 'accessing' }
MGConceptField >> kind [
	^ kind
]

{ #category : 'accessing' }
MGConceptField >> kind: anObject [
	kind := anObject
]

{ #category : 'accessing' }
MGConceptField >> multivalued [
	^ multivalued == true
]

{ #category : 'accessing' }
MGConceptField >> multivalued: aBoolean [
	multivalued := aBoolean
]

{ #category : 'accessing' }
MGConceptField >> name [
	^ name
]

{ #category : 'accessing' }
MGConceptField >> name: anObject [
	name := anObject
]

{ #category : 'printing' }
MGConceptField >> printOn: aStream [
	super printOn: aStream.
	aStream
		nextPut: $(;
		nextPutAll: (name ifNil: [ '?' ]);
		nextPutAll: ': ';
		nextPutAll: ([ self typeString ] on: Error do: [ '?' ]);
		nextPut: $)
]

{ #category : 'accessing' }
MGConceptField >> property [
	^ property
]

{ #category : 'accessing' }
MGConceptField >> property: anObject [
	property := anObject
]

{ #category : 'accessing' }
MGConceptField >> scalarName [
	^ scalarName
]

{ #category : 'accessing' }
MGConceptField >> scalarName: anObject [
	scalarName := anObject
]

{ #category : 'initialization' }
MGConceptField >> setName: aName property: anFM3Property kind: aSymbol scalarName: aScalarName target: aConceptOrNil multivalued: aBoolean [

	name := aName.
	property := anFM3Property.
	kind := aSymbol.
	scalarName := aScalarName.
	target := aConceptOrNil.
	multivalued := aBoolean
]

{ #category : 'accessing' }
MGConceptField >> target [
	^ target
]

{ #category : 'accessing' }
MGConceptField >> target: anObject [
	target := anObject
]

{ #category : 'accessing' }
MGConceptField >> typeName [
	"Name of the scalar or of the object type (MooseEntity when the target is nil) of the field"

	self isScalar ifTrue: [ ^ scalarName ].
	^ target ifNil: [ 'MooseEntity' ] ifNotNil: [ :concept | concept typeName ]
]

{ #category : 'accessing' }
MGConceptField >> typeString [
	"GraphQL type of the field: S or [S] for scalars, T or [T!]! for relations"

	self multivalued ifFalse: [ ^ self typeName ].
	^ self isScalar
		  ifTrue: [ '[' , self typeName , ']' ]
		  ifFalse: [ '[' , self typeName , '!]!' ]
]
