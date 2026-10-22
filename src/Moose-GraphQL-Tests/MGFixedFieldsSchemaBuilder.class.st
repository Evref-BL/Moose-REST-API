"
Test support: a schema builder working on hand-built MGConcept objects (see #objects:interfaces:) whose fields are preset, so that #computeFields only runs its interface fixpoint (used by MGModelSchemaTest>>#testInterfaceFieldDroppedWhenIncompatible).
"
Class {
	#name : 'MGFixedFieldsSchemaBuilder',
	#superclass : 'MGModelSchemaBuilder',
	#category : 'Moose-GraphQL-Tests',
	#package : 'Moose-GraphQL-Tests'
}

{ #category : 'fields' }
MGFixedFieldsSchemaBuilder >> fieldSpecsOf: aConcept [
	"Answer the fields preset on aConcept instead of computing them from FM3"

	^ aConcept fields
]

{ #category : 'initialization' }
MGFixedFieldsSchemaBuilder >> objects: objectCollection interfaces: interfaceCollection [
	"Install hand-built object and interface concepts instead of collecting them from a model"

	objectConcepts := Dictionary new.
	objectCollection do: [ :each | objectConcepts at: each fm3Type put: each ].
	interfaceConcepts := Dictionary new.
	interfaceCollection do: [ :each | interfaceConcepts at: each fm3Type put: each ].
	implementers := Dictionary new
]
