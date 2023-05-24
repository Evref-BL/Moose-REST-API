Class {
	#name : #MRModelInformation,
	#superclass : #MRModelMinimalInformation,
	#instVars : [
		'size'
	],
	#category : #'Moose-REST-API-Model'
}

{ #category : #accessing }
MRModelInformation class >> neoJsonMapping: mapper [

	mapper for: self do: [ :mapping | mapping mapAllInstVars ]
]

{ #category : #accessing }
MRModelInformation >> size1 [

	"I represent the number of elements inside the model"

	<OPEN_API_variable: #size type: #integer>
	^ size
]

{ #category : #accessing }
MRModelInformation >> size: anObject [

	size := anObject
]
