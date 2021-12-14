"
I am a custom extension that can be added to the web part
"
Class {
	#name : #MRExtension,
	#superclass : #Object,
	#category : #'Moose-REST-API'
}

{ #category : #accessing }
MRExtension >> canReceiveEntity: anObject [
	"determine if this can be shown"
	^ self subclassResponsibility
]

{ #category : #accessing }
MRExtension >> followEntity: anEntity [
	"Return the data that will be displayed for the followed entity"
	^ self subclassResponsibility
]

{ #category : #accessing }
MRExtension >> title [
	^ self subclassResponsibility
]
