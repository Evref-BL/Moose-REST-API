Class {
	#name : #MRUMLExtension,
	#superclass : #MRExtension,
	#instVars : [
		'diagram'
	],
	#category : #'Moose-REST-API'
}

{ #category : #accessing }
MRUMLExtension >> canReceiveEntity: anObject [

	"can't use isType because it can be a MooseModel (that does not answer isType)"

	anObject isMooseObject ifFalse: [ ^ false ].
	^ (anObject isKindOf: FamixTypeGroup) or: [ 
		  anObject isOfType: FamixTType ]
]

{ #category : #accessing }
MRUMLExtension >> followEntity: anEntity [

	^ String streamContents: [ :stream | 
		  | canvas |
		  canvas := MiUML new
			            rootEntities: anEntity asMooseGroup specialize;
			            run;
			            canvas.
		  canvas svgExporter exportToStream: stream ]
]

{ #category : #accessing }
MRUMLExtension >> title [
	^ 'UML'
]
