Class {
	#name : #MRDependencyButterflyExtension,
	#superclass : #MRExtension,
	#instVars : [
		'diagram'
	],
	#category : #'Moose-REST-API'
}

{ #category : #accessing }
MRDependencyButterflyExtension >> canReceiveEntity: anObject [
	^ anObject isMooseEntity
		and: [ anObject usesFamixTrait: TEntityMetaLevelDependency ]
]

{ #category : #accessing }
MRDependencyButterflyExtension >> followEntity: anEntity [

	^ String streamContents: [ :stream | 
		  | canvas |
		  canvas := MiDependencyButterfly new
			            entity: anEntity;
			            run;
			            canvas.
		  canvas svgExporter exportToStream: stream ]
]

{ #category : #accessing }
MRDependencyButterflyExtension >> title [
	^ 'DependencyButterfly'
]
