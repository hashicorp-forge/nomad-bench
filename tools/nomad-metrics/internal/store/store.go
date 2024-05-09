// Copyright (c) HashiCorp, Inc.
// SPDX-License-Identifier: MPL-2.0

package store

type Load interface{ Run() error }

type Transform interface{ Run() error }
