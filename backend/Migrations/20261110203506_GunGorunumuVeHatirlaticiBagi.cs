using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class GunGorunumuVeHatirlaticiBagi : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "GorevKimligi",
                table: "Hatirlaticilar",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Gunler",
                table: "Hatirlaticilar",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "MaddeId",
                table: "Hatirlaticilar",
                type: "character varying(120)",
                maxLength: 120,
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "MaddeTarihi",
                table: "Hatirlaticilar",
                type: "date",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "BirakilanMaddeler",
                columns: table => new
                {
                    Tarih = table.Column<DateOnly>(type: "date", nullable: false),
                    MaddeId = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    KullaniciId = table.Column<Guid>(type: "uuid", nullable: false),
                    BirakmaAni = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BirakilanMaddeler", x => new { x.Tarih, x.MaddeId, x.KullaniciId });
                });

            migrationBuilder.CreateTable(
                name: "GunAyarlari",
                columns: table => new
                {
                    Id = table.Column<int>(type: "integer", nullable: false),
                    HaftaIciDk = table.Column<int>(type: "integer", nullable: false),
                    HaftaSonuDk = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GunAyarlari", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Hatirlaticilar_GorevKimligi",
                table: "Hatirlaticilar",
                column: "GorevKimligi");

            migrationBuilder.CreateIndex(
                name: "IX_Hatirlaticilar_MaddeTarihi_MaddeId",
                table: "Hatirlaticilar",
                columns: new[] { "MaddeTarihi", "MaddeId" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "BirakilanMaddeler");

            migrationBuilder.DropTable(
                name: "GunAyarlari");

            migrationBuilder.DropIndex(
                name: "IX_Hatirlaticilar_GorevKimligi",
                table: "Hatirlaticilar");

            migrationBuilder.DropIndex(
                name: "IX_Hatirlaticilar_MaddeTarihi_MaddeId",
                table: "Hatirlaticilar");

            migrationBuilder.DropColumn(
                name: "GorevKimligi",
                table: "Hatirlaticilar");

            migrationBuilder.DropColumn(
                name: "Gunler",
                table: "Hatirlaticilar");

            migrationBuilder.DropColumn(
                name: "MaddeId",
                table: "Hatirlaticilar");

            migrationBuilder.DropColumn(
                name: "MaddeTarihi",
                table: "Hatirlaticilar");
        }
    }
}
