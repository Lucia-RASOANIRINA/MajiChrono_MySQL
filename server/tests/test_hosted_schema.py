"""Le mapping ORM doit référencer les tables hébergées (colonnes à adapter)."""

from app.models import (
    Account,
    Conversation,
    Delivery,
    DeliveryEvent,
    Dispute,
    DisputeMessage,
    DriverState,
    Message,
    PaymentIntent,
    PositionSample,
    Review,
    SavedAddress,
)


def test_les_modeles_referencent_les_tables_hebergees():
    assert {
        Account.__tablename__,
        SavedAddress.__tablename__,
        Delivery.__tablename__,
        DeliveryEvent.__tablename__,
        DriverState.__tablename__,
        PositionSample.__tablename__,
        PaymentIntent.__tablename__,
        Review.__tablename__,
        Conversation.__tablename__,
        Message.__tablename__,
        Dispute.__tablename__,
        DisputeMessage.__tablename__,
    } == {
        "users",
        "addresses",
        "deliveries",
        "delivery_events",
        "drivers",
        "location_pings",
        "payments",
        "reviews",
        "conversations",
        "conversation_messages",
        "reclamations",
        "reclamation_messages",
    }


def test_aucune_table_legacy_n_est_declaree():
    names = {table.name for table in Account.metadata.sorted_tables}
    assert not {"accounts", "saved_addresses", "driver_states", "position_samples"} & names
