package request

type CreateTransaction struct {
	SourceAccount int64   `json:"source_account"`
	DestAccount   int64   `json:"dest_account"`
	Amount        float64 `json:"amount"`
}
