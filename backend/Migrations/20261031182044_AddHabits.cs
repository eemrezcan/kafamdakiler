using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class AddHabits : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Aliskanliklar",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Ad = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Tur = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Ikon = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    Renk = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    Olcu = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    HedefYonu = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    GunlukHedef = table.Column<int>(type: "integer", nullable: true),
                    Birim = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: true),
                    OgeEtiketi = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: true),
                    AltBaslikEtiketi = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: true),
                    Siklik = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    HaftalikSayi = table.Column<int>(type: "integer", nullable: true),
                    Gunler = table.Column<int>(type: "integer", nullable: true),
                    Sira = table.Column<int>(type: "integer", nullable: false),
                    Arsivlendi = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Aliskanliklar", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Dosyalar",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    DiskAdi = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    IcerikTuru = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    Boyut = table.Column<long>(type: "bigint", nullable: false),
                    YuklenmeAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Dosyalar", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "AliskanlikKayitlari",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    AliskanlikId = table.Column<Guid>(type: "uuid", nullable: false),
                    Tarih = table.Column<DateOnly>(type: "date", nullable: false),
                    Miktar = table.Column<int>(type: "integer", nullable: false),
                    Dakika = table.Column<int>(type: "integer", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AliskanlikKayitlari", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AliskanlikKayitlari_Aliskanliklar_AliskanlikId",
                        column: x => x.AliskanlikId,
                        principalTable: "Aliskanliklar",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Ogeler",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    AliskanlikId = table.Column<Guid>(type: "uuid", nullable: false),
                    Ad = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    AltBaslik = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    Toplam = table.Column<int>(type: "integer", nullable: true),
                    BaslangicKonumu = table.Column<int>(type: "integer", nullable: false),
                    FotografId = table.Column<Guid>(type: "uuid", nullable: true),
                    Durum = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    BaslamaTarihi = table.Column<DateOnly>(type: "date", nullable: true),
                    BitisTarihi = table.Column<DateOnly>(type: "date", nullable: true),
                    Puan = table.Column<int>(type: "integer", nullable: true),
                    Not = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Ogeler", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Ogeler_Aliskanliklar_AliskanlikId",
                        column: x => x.AliskanlikId,
                        principalTable: "Aliskanliklar",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_Ogeler_Dosyalar_FotografId",
                        column: x => x.FotografId,
                        principalTable: "Dosyalar",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "Oturumlar",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    OgeId = table.Column<Guid>(type: "uuid", nullable: false),
                    Tarih = table.Column<DateOnly>(type: "date", nullable: false),
                    BaslangicKonum = table.Column<int>(type: "integer", nullable: false),
                    BitisKonum = table.Column<int>(type: "integer", nullable: false),
                    Dakika = table.Column<int>(type: "integer", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Oturumlar", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Oturumlar_Ogeler_OgeId",
                        column: x => x.OgeId,
                        principalTable: "Ogeler",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AliskanlikKayitlari_AliskanlikId_Tarih",
                table: "AliskanlikKayitlari",
                columns: new[] { "AliskanlikId", "Tarih" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Ogeler_AliskanlikId",
                table: "Ogeler",
                column: "AliskanlikId");

            migrationBuilder.CreateIndex(
                name: "IX_Ogeler_FotografId",
                table: "Ogeler",
                column: "FotografId");

            migrationBuilder.CreateIndex(
                name: "IX_Oturumlar_OgeId_BitisKonum",
                table: "Oturumlar",
                columns: new[] { "OgeId", "BitisKonum" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AliskanlikKayitlari");

            migrationBuilder.DropTable(
                name: "Oturumlar");

            migrationBuilder.DropTable(
                name: "Ogeler");

            migrationBuilder.DropTable(
                name: "Aliskanliklar");

            migrationBuilder.DropTable(
                name: "Dosyalar");
        }
    }
}
