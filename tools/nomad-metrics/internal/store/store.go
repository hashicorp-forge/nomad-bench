package store

type Load interface{ Run() error }

type Transform interface{ Run() error }
