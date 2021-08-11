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
		'maxDepth',
		'exporter'
	],
	#category : #'Moose-REST-API'
}

{ #category : #'initialize-release' }
MRJSONWriter >> initialize [
	super initialize.
	currentID := 0.
	mapInstanceToID := Dictionary new.
	currentDepth := 0.
	maxDepth := 3.
	exporter := MRModelExporter new
]

{ #category : #writing }
MRJSONWriter >> writeMooseEntity: aMooseEntity [
	writeStream
		nextPutAll:
			(String
				streamContents: [ :stream | 
					exporter printer: (MRJSONPrinter on: stream).
					exporter
						model: (FMModel withMetamodel: aMooseEntity mooseModel metamodel).
					exporter exportEntity: aMooseEntity ])
]
