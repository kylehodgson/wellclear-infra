    // WellClear deviation (this repo's README): Remote ID drones carry
    // synthesized ICAOs in the unassigned 'FF' prefix (rid2all convention —
    // no real aircraft can hold it), so the hex alone identifies a Remote ID
    // aircraft. Force the Q4 (rotorcraft UAS) type so getBaseMarker selects
    // the multicopter marker. The aircraft db is not consulted because
    // SBS-ingested aircraft never populate it (verified: readsb net_io.c).
    // NOTE: this.icao is the raw hex from aircraft.json — LOWERCASE.
    if (typeof this.icao === 'string' && this.icao.slice(0, 2).toUpperCase() === 'FF')
        icaoType = 'Q4';
