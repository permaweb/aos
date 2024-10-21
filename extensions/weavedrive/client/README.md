# WeaveDrive Client

Version: 0.0.2

This client allows users to connect to WeaveDrive and access the block headers and transaction headers for Arweave.

## functions

### getTx(txId)

getTx takes a arweave txId and returns the transaction headers for that tx

```json
{
  "format": 2,
  "id": "BNttzDav3jHVnNiV7nYbQv-GY0HQ-4XXsdkE5K9ylHQ",
  "last_tx": "jUcuEDZQy2fC6T3fHnGfYsw0D0Zl4NfuaXfwBOLiQtA",
  "owner": "posmE...psEok",
  "tags": [],
  "target": "",
  "quantity": "0",
  "data_root": "PGh0b...RtbD4",
  "data_size": "123",
  "reward": "124145681682",
  "signature": "HZRG_...jRGB-M",
  "ownerAddress": "WALLET_ADDRESS"
}
```

> NOTE: It is important to note that the owner Wallet Address is added to this result set.

### getDataItem(id)

getDataItem takes a L2 or bundled txId and returns the MetaData for that `id`


### getBlock(blockHeight) 

getBlock takes a blockHeight and returns the blockHeight Headers

```json
{
  "hash_preimage": "zxjxIc7BEGfCZOvhA599qRjuVfnTjnTPP4r2SVnn44I",
  "recall_byte": "20038419977588",
  "reward": "1465707980036",
  "previous_solution_hash": "______DyF1XD_nHsnEh6pdyYJ-0oHn0DCUyqN4Akkx8",
  "partition_number": 5,
  "nonce_limiter_info": {
    "output": "s2a28R-wRiQ-iM53XsYcgydB6sxj1QvDT4SYdBWcW1M",
    "global_step_number": 80,
    "seed": "AM7rbYBtYzJMmX9D5A6LEPAAE02yN-4LzsSKAk459Lpao_M0JUhUK_53Yp6_7bNb",
    "next_seed": "gMsCnK2EimYg8wvEt7BvOFvyFLZGsu5HSJ48cpTklxyzYsMB2E3NDRRAv4mTD1jb",
    "zone_upper_bound": 134783121793270,
    "next_zone_upper_bound": 134792922570998,
    "prev_output": "oJJOt_1wU0qGKC23r95R-OuL5ei_Z4XJrGGG2NPl9qk",
    "last_step_checkpoints": [
      "s2a28R-wRiQ-iM53XsYcgydB6sxj1QvDT4SYdBWcW1M",
      "n8jGN9BxH-_63bDGekTZCVQyigsYhVN2VFfxcTmtWLQ",
      "ZMbGYkazClEaZgQQeeLN0pzTmzvOT6TDFwc4ClLYnfs",
      "FgG2VW4m-gnWwUEsytFWZFa3n0A_cRpXr5tGjaT7iT8",
      "vrOEpUDmPdEtU1rVat9ddRaQFILyXZgPd-VrzvBsi2s",
      "vvdrlyeNLcpUrjpGYzYfGVKWRGQMYLCDXpmDEYO74Hw",
      "r9XhO0mPBImvlNfzWxuxkBz0KHuOrwyGCoX4ugFu09Y",
      "i7CSZDVzuEMaf1zamSr-YcdzFDUBly_WuXdtJdCn7Wk",
      "nJx3ORNUhrc7aXBIBZS5jzMVj0JoyKdn1_H0fUVUWgw",
      "VS_M6lvFUuEAb0XGUb43Zcy5mWj4OqvMDlF7pqgVd_0",
      "1-QEzyO_bjFiGnq59fujRA9dXdRNbzPKIrSHwLs7bOY",
      "JAiHlkIl2KO_oLB3Wmd3Z3mG1pVB7TnObZkjVLa3tQ4",
      "H0vGq1vw54qyyZ8cUJDORzKsP6Ka4fZtEHF2RDbjhtk",
      "D2EMFw_MywM2prEtC9VBY7ABJXYmKklZH3h_7U-QTKE",
      "frqJdF717fyV4fHmlCFQMbnGAnf1ue--0DhCuTwM5iY",
      "y10LgNaDO3_v1-mCrkWm_AcosrLu72_CqlmXqcTVRoQ",
      "na6qGtR67t2ild7LHqtrDiIiLjwSaR4NtXdR9tbGeuU",
      "7k04qTS4utzamCEtiavGdybZGDOXncGUbL7cz-EbUHo",
      "A_8B316ZJ2ynQPKZ4sQsou43-4RTYdhEw8AgqfPENy4",
      "v4_bsH7A7RzrKHf_yXmOGusnwxCX0TqKvN8y-43Thus",
      "9oc9zPu-yBNRIygEuuN1NpylTnhAEVAl7LDQIex4TrA",
      "sUGDC7p_EEa-crTDuLZpfiKmpgp3aGK-Kbo7mLDR_BU",
      "cEo95Mvy5NZAiboJTWa7uW0SUYjqgdaaSYWIcpHv99g",
      "JfQuVzhCZOlFslAwOxO5dT4WCGUb1x-N_a_1DV-KOs4",
      "bCjdytXpTamI8Dn5LHmQHIS86PB5aTG6UxGFvGSUbls"
    ],
    "checkpoints": [
      "s2a28R-wRiQ-iM53XsYcgydB6sxj1QvDT4SYdBWcW1M",
      "8w2UXIcPI-4TMzlLokT6PlLXEt8CvwuUyAh2kvT4l9Q",
      "o3mHmozBtKAW_vs96ANIxaOoul3Td1g6eoR6rvKLV4Y",
      "7M-lVdz0C8JHo3Tx9ZlXG6mlpzlSQyGiMYo4s1LADi0",
      "46ZaCstUm1fVlvgin8b6Md082ydUs2EqhNgx6k3r1ig",
      "uJwPMNNFP_asFzQ24M1nM4LCuL64c3VruVOkUKr2JMc",
      "8ozNKZXisTwwQ2jmcMWQjUm83yVmrTsEkfCZX1dlNBg",
      "ONf3U_542veOtgXykDM5ozxDhl5WtDB7EiTYoPJAgcI",
      "rqyIn_morrYURnbImUx7VieAT1BWiD71jLYWXugBI3o",
      "zfsTWFt7KjjQMfewrrqv8jg5U2N7KiVisG27qsDUSR0",
      "4IQaX7HFRnXFAbtBvUI6YOAWkglVoqVrjZeG4XUVcOg",
      "g5LdQ0EfshaCxrl1ZgyR7E4chksc63l314UanvGfaKA",
      "eeRu4FNtC-xLFW9xC97KEtt6hP0yW0WWOHxQ-xhAScw",
      "1cbBFvlBFey9BbPP3_kf34QijkAxBQQSPM5fDMlKdBM",
      "hbpoPfCNS_hokiOwJOjLV2ktUb4vtRIH-zYAZEi1S1Y",
      "104eeVItYcoebsopnNt-pLnQd86Yw9ewZoTT9TfWXO0",
      "SJv6_zA3lbQbDlstObuKaHGTMc63ov2s3D1TFUgPi54",
      "RQ5-kHJ7duWSto17HJa6pxfAasKVsfU_ZKzo7KQEi9M",
      "IexQqVNJSoTIF3qH9nqZnpfFrKzuPGUK2mutdEuq_jk",
      "V6ikLEujYS4UqDiGrodE6_Cm76FLggWVXNaGNqMpCNs",
      "SO6O36Cxb6MqXOSrpaxRnRkTVohySppVdGJxuvmwLuo",
      "2GSiFs37Qam-sC-qHOODNmDk971JBPi3XVvGRTH6CAk",
      "8FLS2KaDOBvFmdxfbQeVHhxzxNPi5qkIrZTrNbJvX00",
      "Kbp3hCAZXUeztkhkU9tVuhBzHBEXsbKPc4rdhDVaCeI",
      "7wv3TtAizWk0g4BCnlK235aPAaVrz_aIMTT36yknGkw",
      "_Ztkvdyiln7-wdjcpACVruCdvy4UwG93y9Cam73iqGg",
      "x2Xv9GjYeKC0_wqa3DjKX-CB17uZp9IJdHrl8dRFoew",
      "wnOLZndTnQ7Myp77hon0DPoe-PR9HiQKlAuQEdPbof4",
      "q7bP0sGua5zMpHgI_e0-XRb9PHNn_bsNjg1KN1XVmYw",
      "PBtm8ftDalbk5OpcKQfTnFwcmeTm9kg2wOUH0gbgo1g",
      "VEvjbgAIQFxEIAGmhNO6QUsyMKmSVNFN2OHbRXXHrh0",
      "AZUB8jjMwtxrYkguPob0n4PCf3P1yYQgr4pK2CbKQy0",
      "SE7pHN0fiAsFjEFS84MmERhUuAi0ld3M7Ip2tjElDWY",
      "ukCdukTb9LxDlcPdKNElcBaXHsIavK2cChMJUw3Uz1g",
      "FWnsPp-Mb1nMjxU-esQRRzHoSHnsR260ie6FiLPDXSY",
      "AJhvOqQpK_DyGyfaw21fMPPKB0tNRWFGNpg7RX6g4NM",
      "DrUySBtauxDqj9OmdgxArcrKSuNmKKPXohBKZJoUDU8",
      "5t7ah6zqLfq4T1_mF2xGrcXabMdWIaVA9PH-ff9Fk8E",
      "wXM0ihQIvXx9k-FMRhOM172ePwuu0qCBx1YSmYIFvPg",
      "YDtMxHFZg2dSBNVstInQNbzAGf2f_s_DG92DMzEsklI",
      "y_l2J3rryKkoK8OvcJm_zk6nL3VM35rbS6DrdF0bne4",
      "C4z3A-aPvWPsKYZK23mFyXsJ_wfXOivwX4eQzW8L4AU",
      "NATIlXDQq-l9-H0qbQCD5hx1ZYJ2AZHImNIQibLECic",
      "zK_IvJRs4YzGaeLoR_k5_dGgfnUAUe3ZXi6V0GiEJtU",
      "PujjTCaLIyYdXyo82soGz2l4Tf89vCJZX99V8ljw3Pg",
      "WonkHtnh91sJ_94YiH77ZyQIk6iD8NnLNxoVG4A-Tvc",
      "I-ur7MGpI7MdRjdr4ITJs9LhoZaDrbaO-ZyT6bkvGL8",
      "wKc0p7VybSEGU7rHuXJTb1QxlrjF3uvKwYsclvEtl1w",
      "vaCrMtHQ_VHw2oQY0mphbCl-GxMsA_bltHnN3U5v3mw",
      "5Oo-syJG_4i2uqqJQd7LepKVwzunC9GDRDDZ9eLi4CA",
      "qArgC_F6QvYX7RYPojK-oaIWLQ0RyAAlApbFDWfuuy4",
      "Z1jlbha1kGt03MY8rRq7LM41fEjt1XFnqfKKHrLrdAw",
      "m0FXlq5qokRMxtG8WseIE7C8SWaqCNZRRl2r-SwD4zo",
      "PHvWj-3dseMmABYamSy0G2uOeBijC-S8QPuKkR5mkAU",
      "PJaADkiBfNHHD-PBBvslCYd78sgb75vttCRyqbQGjpo",
      "RPuIij4-rRtpUgDQYk51LBtrxJBcHyrEcQXfcileWfM",
      "2mqvvdBZeHabiz4Gmk3JDF2EVj96AnOACj3eS5uFTcw",
      "5po52oX5qd7QVb_C8hhqR6ngU2oPtniq3J9whalzgNs",
      "jgMX-1tbA0TbiR4UzpCAf31Aj7WJg5eFRwM5215qjZM",
      "JTqXNfFsuwjzx2X7vs_cjb_waPtvR-s-KDtxgLUIAXo",
      "bRG0LDix39KujHgpPQ3bb9xfiZDdK0iqYP8lfkb-IS4",
      "YB_gur8BUk39ed-cSVB7agdx2cHJuOkP2dYdHITTwV8",
      "dzAuPGtmp4XaYh-we4fHqisGKgJMIlB7Dr2Mds1_-yM",
      "nG3_3G773uPGoAdTGT1-xCmCaRJrIJNxD-GcQ9rF5Nw",
      "BCIYXrDyabiA5TzmrkmXuN7VO2TtTm2dll5-tPlUtOI",
      "-oZ2BVhhD4pRa2XiYjbLaQ8cZ3cByeqouhaexcdZ0vo",
      "XZ4RV-ZW03ppM2OT6jHd-Vw6F5tTIAOl-xhHdYF4CXg",
      "EoODt3Y-A_6uUjyO7SIWv7dmvvm_R92d5T1ioxD5kZ4",
      "swF9_kdEQ9xHANHvrfS8_002SL1YKBB56LrRJJLf5dw",
      "WMn8p3N35Nsr-9NCIT3Jm2Wy9gwlqh4Yza8f_dibxxM",
      "yZNXdl7xWN5QiXc5aDqZ4828QS8eDEhkBtd7Zu_wqO4",
      "-esBMMucA2ihMvh0Plsa9xAkrCZtKx0WeWaKT8JSfwc",
      "ViA8mtBrUqGrvOxsKKN3VqKV8Y2WHKJNZgZMnX55S9w",
      "wM7YGSJPX2PLa8yiaib9gv9d6tbU30kBzRF287yALHw",
      "dRJm9u7N7Ea3JiXd9c1eOYVYV4FTgSDz5Wj7PF6bwrU",
      "crkNSGwg1XC5Pn_f9jC4y-6930TqAd58eoSyu16E2nE",
      "9rzjzw1ezmMxJbd-vOZslE-e__HOAMYTivqGIzcTd6A",
      "vv-AS6Rd-kokfP8wsGAlz2FpnBoM3j6auH-MuzpCq5Q",
      "jKVMzwIEtFxXJtoUUALDuJV5ki8urWX2I_0g5pXZHLk"
    ]
  },
  "poa2": { "option": "1", "tx_path": "", "data_path": "", "chunk": "" },
  "signature": "Ygl9YMlJMrD_lphxulN_n1Y0FJI8OcjvoPcScgZWvhGtg5zTj9Y9LZYREwZrF4PgUq0ktVeYlG4i-Qv1z1QJYgSn7FMX-8SWvjBzgGERdmyxWSeF-DtAwU3JiiInrtilZDZmw3y0QzXKwyzysUeWXQoL1B2Kj0N9swvuENJmiqfY7yWmvUlTFQO-AHr5FHrHRadH3dMrpbNJ4GlithNmNACjBYiqGnrwxH62d_gdc13G4MG3frITkX8lPf5KPAwenUNE2UZ9kv3Yyihog2PXH7x1lx5dfDBCb8uVsNsNxgHAud1krNpNO8ycq2L6-fmEEvAUvsf-YBqeCXjtMYPacOwzWsmPF--6Ed9VT_Om6mGGf0_XZjzuoDl7vQiafdpgW8dtW9qJD8cCmgf_63pltEDRxSkEp_COho293NR84ggN8sJGbXKH0EBFTIAa_ce-hgUy9wP4e18hoLHVLHK737HpJsaxBLoA-JrOUpWoCGT2T910NrIqMo9G-Wsy7xEiSVPaJGfmU4sRJJcjGAj84U4TPp4XJGYps8n-DdW3C2ZA5xCf7fw8Ic7H1JXqYiGUo3isKYkUD7w-7V_FezcnJ7D_znTH5rfkuEvdp3w3f-ZHyKNCdVIC9m2qC-rVOtOOfwAQtRKBK6T8PYpiQLvg3soOVAqIDoGWRVLe8kIqMl8",
  "reward_key": "2LWWYCT6WKJ_AJoxGqicO5gyLg_joq6kHEU_4K-nPcA3dMCZWs7hDkyQcsFrk5sCtSmjJ2C4Rf1M54jLb21-kSE6rxMYZeWtJDldsFuUyEJ8y99p8MWLQohno9t1BDM9cBVIQh4sbV6A8_P4ICv-rTnVfG2YIfGzsz044vUm3kqKXFJW44kBksoktuXOGVPR0ak03TfKu1PgzHm23Ms4u4Ug3-yyDGoNWrHkCkDf3BIxG8lGHc_UrkjN16oG8UgJviyKzZMg59HBgcUeSrgAnSW36zCtFC03_fpfvA0VQpKPFmVFXNts1bMoyUkW2oCvQMhE-iNQkUwv79BO3_NxZZpqLk7HlfB6gQ_0fxHoEIpUnjM8-PRVNFQCHNZ8zdyCHmEZtA2SLlxocLmA5VNyjNChAThT-xYnNijbLLfs1FHjEV4Q_2PYcvV4w8R9hYcveexgRvEc69dEwM3i9Op9QPVX53u0Wi0bqfnHoVZnrNbIJWbpWrLxwHN2j097QaPl-83Pzg63kF6bkyLlpKNMW6sjGSGOOR1yrnUUUnRrM_t_7BD5ZpKoobcQDcwjuUSzIf_ypz51SytPSEL0Kh8-oK5BPEEpvcAuEoZh-X0EXInIKW0eTRn5G9JiuCydHXy4SKwZBhGvTHHY_ZdynOlKPMNYyt05V9DIqno5DlxCLNk",
  "price_per_gib_minute": "6986",
  "scheduled_price_per_gib_minute": "6986",
  "reward_history_hash": "I190QrZCm05s9aIbt9j6bjFJn1BkNvZVMPEXJ7QFTtI",
  "debt_supply": "0",
  "kryder_plus_rate_multiplier": "1",
  "kryder_plus_rate_multiplier_latch": "0",
  "denomination": "1",
  "redenomination_height": 0,
  "double_signing_proof": {},
  "previous_cumulative_diff": "4369104305356760",
  "usd_to_ar_rate": ["8855", "524288"],
  "scheduled_usd_to_ar_rate": ["1", "10"],
  "packing_2_5_threshold": "0",
  "strict_data_split_threshold": "30607159107830",
  "nonce": "AQ8",
  "previous_block": "gMsCnK2EimYg8wvEt7BvOFvyFLZGsu5HSJ48cpTklxyzYsMB2E3NDRRAv4mTD1jb",
  "timestamp": 1678092233,
  "last_retarget": 1678092233,
  "diff": "115792084401224566807772651152730092358388734887252574358647557874619658061534",
  "height": 1132210,
  "hash": "____09aYjKvcwjKp_Qb444oIiJVpbSxJF3o21jBOwFU",
  "indep_hash": "7OkBVCwRpf-w5B-yKClukNEzDbyV4Cs1Jlc65WmL-uR4gu6ZisocC2gHufg0wHVe",
  "txs": [
    "fzuqZGVS5FvX_EsSxAB670ZLYT4cWGI8Ais-CeF7Sc4",
    "x2jV0Y_g67VCTJxI-BxP9VtHkWbzfKdvRtRUieYCAeo",
    "Kr95NEJ_lhWm_k0iw13G5d0j7-96a03SEAI4BSPTUus",
    "zzaw9uCdk_Ic679oFMzDLKKcnzngROU1GYHSqEBrTN4",
    "6VuOwldWcQKi6DaIIs5zCf5MMLUxKhCY0bf6eZXvYew",
    "2IPzj7-LShrohdJdOttYQJDrL-AQTZ82Xy2ECv829-w",
    "Tw5WQjRhm5JKpzSIefX8OU47eMqG6YdBx7Hy7kwq45o",
    "JJcSEzZU3wOqJNDTTA0bSGO_akvkm6DECLQc78jdKAs",
    "PFfKmEk6q7HNjEzrirrjLMZfVD6vvnNUIvTa12VqIb8",
    "2N9aoBB21Sq7X3e7sn9oK4aRwjQJj-0RZQsdtSPT0_E",
    "WdwA5PGd6Ah5l2BGY0l0pHd7n1q_mzipydhwSqCXvzI",
    "ikTT02RSNwJtD5jHEScfjTkxMa-5tGmvyAPjzWdenL8",
    "oxubxfn5AK3fCQCO-3sKQS1i14AH-iPhswyBWo8rCCw",
    "uNdOaUP70uioo15K2wAlPkJ1H4MkOhhYRTKy81Wzj_U",
    "NsIOyrSB2o3RSMcb2WrfV7xRUfwCEkpnnCvez5FozuM",
    "pyxDgRreB52B-sYv5lS_6EOJhY5EzYaJVp29d1YDB9A",
    "unahGYmRyN8pahTiij9aS1T4Ind0HtpU92lltprIoqg",
    "vG1WlB2y8t_1ePuOt2oRudUoUjjDuQ1HlIeMNH7Nc6Q",
    "UbHFan5Tqwnau4CyiVxEO3DoxzGctr9udIUcqsYAUYM"
  ],
  "tx_root": "jHMSGnQUPqGM21zwVi2EFpJrHmjrLDqyavxodjC61mw",
  "wallet_list": "Y17X1la5YZWup2Q0tn7YQVizb8fs2R8OY1KUmqLayeU_SBEEDTHp9PgtR_90kWS3",
  "reward_addr": "SOtIrcaiJwVs4h3yqXKjOs0P9bNJG5F77y0-TilnQ2U",
  "tags": [],
  "reward_pool": "46030523196756537",
  "weave_size": "134792975261942",
  "block_size": "52690944",
  "cumulative_diff": "4369104329300079",
  "hash_list_merkle": "iMx_IwEe6lEGXGBqFr0NXl5AtQYPb9HILU8FD3nNqXvoqgqvoriXTiSeW7PmtCtF",
  "poa": {
    "option": "1",
    "tx_path": "mTA_E-nj8VL4XjyQp0PX8wmQYHqTTBQ-TQR9p8ySBK9WNjzAci0Wh9FgYIjVgSNhtNz-G8dJfPz-1L1DOoiDIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAuuY4QTEhLRfqmYdRvKQ0Ln1c5Fz3zlhqKUBRfpnFPUs1WhbuFCYjZjjZgjv1kILQDY9HQJa6GT1qKdYhPnAHukOIKDgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAbhl1-TXlZj7Sm7u5ZXWQfd4pUdYeoEMLhe0Nm6YqDrHt6uudfzVBHQ-qnHZtwXYZoTD65f_IYLwN-gO6ygJCwzU566QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAASL4xgq6YQAokrDGhdVpXVw1oIwDNvuNOVnxgLeK02xsFp4elqLw2vEwR6uZ4YixqDFunCOSz68pkB-q6Dt3T2r-fRJAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWnvsAuuGc3Ra9YSnuHmXpv_Tca7IYW2O3Qb12ojYIbWggC5fUJzChVVm_01A57dvpI3KSBxrofHRWsc9BZU6ecpulBQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAbf7IdSwQ66LRKwxoIMIQFMI5-fNZJE4ZzQH5r2MEE3zhV1fwZXBxJLfaavp2TI7F9c6gFLdIHxNKGjyye1tq3ucC4vgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWoJCnFnlRI-1gWVLTT6oNSfHB8JehHhdRza0LedElmr9K6wmQQd4guZNFdOUYt-2LRA4HAWCavdRr6eIl28NPJQkiKAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAWoJ16-86ZLi5VeUTqYq3lCWI-KYwYbJ-TzugMbY7Z5gT3DdIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAG3-yHQ",
    "data_path": "TuqqNP9Hk2K6cDU8PDSp_BC5cHvjYJk2KrMM-uP_fOiWOBeOg1n1qdP3k-zDFDZ4YAhylENe6zjR_BA5EvufCwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAArDlTG5drIK1C9IeuYvLqv6NmJYbJvxFNoCMeoIZZasMwMUA4MxR3sLjRYwcKtq8L1PQC7-T6GWo3-hcnH958MwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAAAhKyWpTMsE_StjgwW1PNFdH7xN_SBY14weoeonM_wXsYNJT8IpMkfAXfFiKSn6T55OKeT2Pw2QgEcJMMSW8R1AwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAAAAR3a4pdzYsSjFYGc3KC9ZFYxe-lksRbGzoUQGkz9jdeEQtx0uFuPGUGPycoWo-RXyCFJH_Zf4x9880NcG5Y6R0QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADgAAAlcA-Z6ojqsWBwqJsMk-nibjOtOcKURTzWOd3awrhVRIPeYosVskIql7V-_ix188TrLm-AIjzWtMH7Q44WCzTSgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADwAAAET9zJFpjrYti3st1dvhztjDsoV1rnc-JdO2HQLsOdIbe8mTHJ8sn-EzKR4WHt-pdW4SdaTeBvTnbaP47ttwI8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD4AAAb01i3lbiGlAds8x1ywEBzeb0lUMzGpV8t6AfIm2zLaDVFJIGy4oI4ouX8FXhq5mbXAs8_faexv8cVAUKGADQIQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD0AAA9EZm_6-QghTZb3NV2kQZcQJR50VcQPXIdrLXDKveFNWvD4MgV-RVn4_k4gqiRr5QbrxvbjwbS0m-7oStNrAh5AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD2AAAs6AhgIw3KFviltC_gBcRfDt_BxxMUlOMDbZcoO_tHsSAaTbg8kiOAXI7ZddFpYlbn3m85-UTIFiSHSzhwuSmsAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD3AAA7_heFX0YS58BmcACzOdu8u7AjUnht-8OJkpVIm7VwOAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA-AAAA",
    "chunk": "vsLWa3iv1i8VxoQN6coorkRAWveASY6brn..."
  }
}
```

## Publish

```
npm i -g apm-tool
apm publish
```

