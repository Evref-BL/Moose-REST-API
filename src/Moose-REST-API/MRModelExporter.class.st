Class {
	#name : #MRModelExporter,
	#superclass : #FMModelExporter,
	#category : #'Moose-REST-API'
}

{ #category : #exporting }
MRModelExporter >> exportEntity: each [
	| meta |
	meta := model metaDescriptionOf: each.
	printer
		inEntity: meta fullName
		do: [ printer serial: (self indexOf: each).
			printer internalId: each mooseID.
			((self sortedPropertiesOf: meta)
				select: [ :property | self shouldExportProperty: property for: each ])
				do: [ :property | self exportProperty: property for: each ]
				separatedBy: [ printer printPropertySeparator ] ].
]
