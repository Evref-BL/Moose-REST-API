Class {
	#name : #MRModelMetaInformation,
	#superclass : #MRModelMinimalInformation,
	#instVars : [
		'size'
	],
	#category : #'Moose-REST-API-Model'
}

{ #category : #accessing }
MRModelMetaInformation class >> neoJsonMapping: mapper [

	mapper for: self do: [ :mapping | mapping mapAllInstVars ]
]

{ #category : #accessing }
MRModelMetaInformation >> size1 [

	"I represent the number of elements inside the model"

	<OPEN_API_variable: #size type: #integer>
	^ size
]

{ #category : #accessing }
MRModelMetaInformation >> size: anObject [

	size := anObject
]
